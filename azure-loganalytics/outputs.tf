output "workspace_id" {
  value       = azurerm_log_analytics_workspace.this.id
  description = "Resource id, which the managed environment consumes."
}

output "customer_id" {
  value       = azurerm_log_analytics_workspace.this.workspace_id
  description = "Workspace GUID, which queries and dashboards use."
}
