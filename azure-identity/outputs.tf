output "id" {
  value       = azurerm_user_assigned_identity.this.id
  description = "Resource id, attached to the Container App and named in role assignments."

  # A Container App that names this identity pulls its image with it on
  # creation. Waiting here, rather than on the identity alone, is what keeps
  # the app from being created before it can pull.
  depends_on = [azurerm_role_assignment.registry_pull]
}

output "principal_id" {
  value       = azurerm_user_assigned_identity.this.principal_id
  description = "Object id of the service principal, for role assignments."
}

output "client_id" {
  value       = azurerm_user_assigned_identity.this.client_id
  description = "Client id, which the app uses to select this identity at runtime."
}
