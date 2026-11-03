# Where the Container Apps environment sends console output and system logs.
#
# PerGB2018 is the only SKU still open to new workspaces; the older tiers are
# rejected on creation, so it is fixed here rather than exposed as a variable.
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = var.tags
}
