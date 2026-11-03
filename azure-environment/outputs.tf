output "id" {
  value       = azurerm_container_app_environment.this.id
  description = "Resource id, which every Container App in this environment references."
}

output "default_domain" {
  value       = azurerm_container_app_environment.this.default_domain
  description = "Domain suffix of app FQDNs, for smoke tests and documentation."
}

output "static_ip_address" {
  value       = azurerm_container_app_environment.this.static_ip_address
  description = "Ingress IP, for a DNS record or a firewall rule."
}
