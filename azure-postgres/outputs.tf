output "host" {
  value       = azurerm_postgresql_flexible_server.this.fqdn
  description = "Server FQDN, exposed to env[].fromModule as postgres.host. Resolves to a private address when the server is in a delegated subnet."
}

output "port" {
  value       = 5432
  description = "Fixed by Azure, exposed to env[].fromModule as postgres.port."
}

output "database" {
  value       = var.databases[0]
  description = "First database on the server, exposed to env[].fromModule as postgres.database."
}

output "username" {
  value       = azurerm_postgresql_flexible_server.this.administrator_login
  description = "Administrator login, exposed to env[].fromModule as postgres.username. Not a secret; the password is not an output."
}

output "connection_string_secret" {
  value       = azurerm_key_vault_secret.connection_string.name
  description = "Name of the Key Vault secret holding the connection string, exposed to env[].fromModule as postgres.connectionStringSecret. The name, never the value."
}

output "server_id" {
  value       = azurerm_postgresql_flexible_server.this.id
  description = "Resource id, for a diagnostic setting or a role assignment."
}
