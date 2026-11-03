output "id" {
  value       = azurerm_container_app.this.id
  description = "Resource id, for an alert rule or a diagnostic setting."
}

output "name" {
  value       = azurerm_container_app.this.name
  description = "App name, which the run's traffic-shift and rollback steps address."
}

output "fqdn" {
  value       = one(azurerm_container_app.this.ingress[*].fqdn)
  description = "Ingress hostname, which the smoke tests call. Null when the app has no ingress."
}

output "latest_revision_name" {
  value       = azurerm_container_app.this.latest_revision_name
  description = "Revision created by the most recent apply. The traffic-shift step names this revision when it moves weight onto it."
}

output "outbound_ip_addresses" {
  value       = azurerm_container_app.this.outbound_ip_addresses
  description = "Source addresses for outbound calls, for a firewall rule on something the app reaches."
}
