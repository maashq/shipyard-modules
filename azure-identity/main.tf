# One user-assigned identity per project and environment (ADR-0019).
#
# User-assigned rather than system-assigned because a system-assigned identity
# does not exist until its Container App has been created, while the app cannot
# be created with a key_vault_secret_id unless an identity already has read
# access to that vault. Terraform cannot break that within a single apply. An
# identity that exists before both removes the cycle rather than working around
# it.
resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Pull access to the tenant registry (ADR-0006), granted where the identity is
# created rather than in the app module, for the reason azure-keyvault grants
# secret access: the app pulls its image while it is being created, so the
# assignment has to exist first. The `id` output waits for it.
#
# AcrPull and nothing wider. Pushing is the deploy identity's, never the app's.
resource "azurerm_role_assignment" "registry_pull" {
  for_each = toset(var.pull_registry_ids)

  scope                = each.value
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
}
