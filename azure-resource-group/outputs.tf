output "name" {
  value       = azurerm_resource_group.this.name
  description = "Resource group name, for every module placed inside it."
}

output "location" {
  value       = azurerm_resource_group.this.location
  description = "Region, so callers pass the location once."
}

output "id" {
  value       = azurerm_resource_group.this.id
  description = "Full resource id, for role assignment scopes."
}
