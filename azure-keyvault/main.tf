# The only place a secret value exists. The spec, this repository and the
# shipyard database hold references, never values.
#
# ## Why the firewall is open by default
#
# trivy raises AZU-0013 on a vault without a deny-by-default network ACL, and
# it is right about the general case. It is not something this module can
# default to, because two things that must reach the vault are outside any
# network we control:
#
#   - Terraform itself writes the generated Postgres credentials here, from a
#     GitHub-hosted runner or from the direct executor. Neither has a stable
#     address, and GitHub's published runner ranges are too large to be a
#     meaningful allowlist.
#   - Container Apps resolves a secret reference at revision start-up. It is
#     not on Key Vault's trusted-services list, so `bypass = "AzureServices"`
#     does not cover it; closing the vault stops apps from starting.
#
# Deny-by-default therefore needs a private endpoint and a vault-scoped subnet,
# which is a separate piece of work with its own cost. Until then the gate is
# RBAC — no access policies, Secrets User for apps, Secrets Officer only for
# the deploying principal — and `var.network_acls` is here so an operator who
# has done that work can close the vault without editing this module.
#
# The suppression itself lives in modules/.trivyignore, with a reason and an
# expiry date, so that a suppression nobody revisits fails the build rather
# than quietly outliving its reason.
resource "azurerm_key_vault" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku

  # RBAC rather than access policies: policies are per-vault ACLs that no
  # subscription-wide review can see, and Azure now treats them as legacy.
  rbac_authorization_enabled = true

  purge_protection_enabled   = var.purge_protection
  soft_delete_retention_days = var.soft_delete_retention_days

  dynamic "network_acls" {
    for_each = var.network_acls == null ? [] : [var.network_acls]

    content {
      default_action             = network_acls.value.default_action
      bypass                     = network_acls.value.bypass
      ip_rules                   = network_acls.value.ip_rules
      virtual_network_subnet_ids = network_acls.value.virtual_network_subnet_ids
    }
  }

  tags = var.tags
}

# Read access for the app identities, granted here rather than in the app
# module: the assignment must exist before the Container App is created, or the
# app's secret block cannot resolve its key_vault_secret_id on first apply.
#
# Secrets User, not Secrets Officer. Reading a secret is what an app does;
# writing one is an operator action that should not ride on a deployment.
resource "azurerm_role_assignment" "secret_readers" {
  for_each = toset(var.reader_principal_ids)

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}
