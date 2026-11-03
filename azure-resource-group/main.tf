# The blast-radius boundary: one resource group per project and environment
# (ADR-0004). Deleting this group deletes that environment and nothing else.
#
# Its own module rather than a resource inside azure-environment, because the
# workspace, the vault and the database all need the group before the managed
# environment exists. Owning it there would put module.environment both before
# and after module.logs, which Terraform rejects as a cycle.
resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags
}
