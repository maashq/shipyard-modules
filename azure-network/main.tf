# The virtual network, present only when something needs to be private.
#
# Its own module rather than part of azure-environment: the managed environment
# and the database each take one subnet from it, and neither owns the other. A
# project with a public database never renders this module at all.
resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}

# The Container Apps control plane subnet.
#
# Delegation is not optional and it is not symmetric. A workload profiles
# environment — the current default, and what azure-environment creates —
# requires this subnet to be delegated to Microsoft.App/environments. The
# legacy Consumption-only environment requires it *not* to be delegated.
# Getting this wrong is an apply-time error, not a plan-time one.
resource "azurerm_subnet" "apps" {
  name                 = "${var.name}-apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.apps_subnet_prefix]

  delegation {
    name = "container-apps"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Azure requires the flexible server to have a subnet to itself, so this one
# holds nothing else and is never shared with the apps subnet above.
resource "azurerm_subnet" "postgres" {
  count = var.postgres_enabled ? 1 : 0

  name                 = "${var.name}-postgres"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.postgres_subnet_prefix]

  delegation {
    name = "postgres-flexible-server"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  count = var.postgres_enabled ? 1 : 0

  name                = var.postgres_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Without this link the zone exists but nothing in the VNet resolves against
# it, so the app gets a name it cannot look up. The server has to be created
# after the link, which the root module expresses with depends_on.
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count = var.postgres_enabled ? 1 : 0

  name                  = "${var.name}-postgres"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags

  depends_on = [azurerm_subnet.postgres]
}
