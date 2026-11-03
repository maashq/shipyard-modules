# The Container Apps managed environment: the shared network and logging
# boundary that every app in this project and environment runs inside.
#
# It does not own the resource group. The workspace, the vault and the database
# all need that group before this environment exists, so owning it here would
# put this module both before and after them — a cycle Terraform rejects at
# validate time. See modules/azure-resource-group.
resource "azurerm_container_app_environment" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  log_analytics_workspace_id = var.log_analytics_workspace_id
  infrastructure_subnet_id   = var.infrastructure_subnet_id

  internal_load_balancer_enabled = var.internal_load_balancer
  zone_redundancy_enabled        = var.zone_redundant

  tags = var.tags

  lifecycle {
    # Both settings are fixed when the environment is created. Changing either
    # replaces the environment, which takes every app in it down and gives them
    # new FQDNs. Terraform would do it without comment; this turns it into an
    # explicit error naming what has to happen instead.
    precondition {
      condition     = var.internal_load_balancer == false || var.infrastructure_subnet_id != null
      error_message = "An internal load balancer requires infrastructure_subnet_id: the environment has to be in a VNet before its ingress can be kept inside one."
    }

    precondition {
      condition     = var.zone_redundant == false || var.infrastructure_subnet_id != null
      error_message = "Zone redundancy requires infrastructure_subnet_id: Azure spreads the environment across zones within a VNet."
    }
  }
}
