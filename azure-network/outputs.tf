output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "Resource id of the virtual network."
}

output "apps_subnet_id" {
  value       = azurerm_subnet.apps.id
  description = "Subnet for the managed environment's infrastructure_subnet_id."
}

output "postgres_subnet_id" {
  value       = one(azurerm_subnet.postgres[*].id)
  description = "Subnet for the flexible server's delegated_subnet_id. Null when postgres_enabled is false."
}

output "postgres_dns_zone_id" {
  value       = one(azurerm_private_dns_zone.postgres[*].id)
  description = "Private DNS zone for the flexible server. Null when postgres_enabled is false."
}
