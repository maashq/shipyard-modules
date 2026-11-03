# The PostgreSQL flexible server, its databases, and the two Key Vault secrets
# an application needs to reach it.
#
# ## Where the administrator password lives
#
# Nowhere a person types it, and nowhere shipyard stores it. Terraform
# generates it, writes it straight into Key Vault, and the application reads
# the connection string from that vault at run time. The spec, this repository
# and the shipyard database hold the secret's *name*, never its value.
#
# The value does exist in Terraform state, which is unavoidable for any
# resource Terraform creates with a password argument. That is precisely why
# ADR-0005 puts state in a storage account with public access off, a delete
# lock and RBAC — the state blob is a secret, and is treated as one.
#
# Terraform 1.11 adds write-only arguments (`administrator_password_wo`) which
# keep the value out of state entirely. policy.terraformVersion is 1.9.8 today,
# so that is a change to make when the floor moves, not a reason to hand-manage
# the password now.
locals {
  # Azure wants tier and size as one string: "B_Standard_B1ms". The spec keeps
  # them apart because Azure rejects mismatched pairs and a single field hides
  # which half is wrong.
  tier_prefix = {
    Burstable       = "B"
    GeneralPurpose  = "GP"
    MemoryOptimized = "MO"
  }

  sku_name = "${local.tier_prefix[var.tier]}_${var.sku}"

  private = var.delegated_subnet_id != null
}

# Restricted to characters that survive a URL without percent-encoding. A
# password containing "@" or "/" produces a connection string that parses as a
# different host, and the failure appears at run time as a DNS error.
resource "random_password" "administrator" {
  length           = 32
  special          = true
  override_special = "-_=+*!"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 2
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = var.postgres_version
  sku_name            = local.sku_name
  storage_mb          = var.storage_gb * 1024

  administrator_login    = var.administrator_login
  administrator_password = random_password.administrator.result

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  # Private access means the server has no public endpoint at all, rather than
  # a public endpoint with a firewall rule in front of it. Azure requires the
  # public listener to be off once a delegated subnet is set.
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = !local.private

  dynamic "high_availability" {
    for_each = var.high_availability ? [1] : []

    content {
      mode = "ZoneRedundant"
    }
  }

  tags = var.tags

  lifecycle {
    # Azure moves the server between availability zones on failover and writes
    # the new zone back. Without this, the next apply drags it back to where it
    # started, which is a failover in the opposite direction.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]

    precondition {
      condition     = var.delegated_subnet_id == null || var.private_dns_zone_id != null
      error_message = "A delegated subnet requires private_dns_zone_id: without the zone the server gets a name nothing in the VNet can resolve."
    }

    precondition {
      condition     = var.high_availability == false || var.tier != "Burstable"
      error_message = "Zone-redundant high availability is not available on the Burstable tier. Use GeneralPurpose or MemoryOptimized."
    }
  }
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  for_each = toset(var.databases)

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# The credentials, as references. Writing these requires the deploying
# principal to hold Key Vault Secrets Officer on the vault; the app identity
# holds Secrets User and can only read them.
resource "azurerm_key_vault_secret" "administrator_password" {
  name         = var.administrator_password_secret_name
  key_vault_id = var.key_vault_id
  value        = random_password.administrator.result
  content_type = "password"
  tags         = var.tags
}

# A complete connection string rather than a password alone: an application
# that assembles one from five environment variables gets the sslmode wrong
# exactly once, in production.
resource "azurerm_key_vault_secret" "connection_string" {
  name         = var.connection_string_secret_name
  key_vault_id = var.key_vault_id
  content_type = "connection-string"
  tags         = var.tags

  value = format(
    "postgresql://%s:%s@%s:5432/%s?sslmode=require",
    var.administrator_login,
    random_password.administrator.result,
    azurerm_postgresql_flexible_server.this.fqdn,
    var.databases[0],
  )
}
