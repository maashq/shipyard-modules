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
