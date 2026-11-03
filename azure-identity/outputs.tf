output "id" {
  value       = azurerm_user_assigned_identity.this.id
  description = "Resource id, attached to the Container App and named in role assignments."
}

output "principal_id" {
  value       = azurerm_user_assigned_identity.this.principal_id
  description = "Object id of the service principal, for role assignments."
}

output "client_id" {
  value       = azurerm_user_assigned_identity.this.client_id
  description = "Client id, which the app uses to select this identity at runtime."
}
