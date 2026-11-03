output "id" {
  value       = azurerm_key_vault.this.id
  description = "Resource id, used to build a secret id for a Container App secret block."
}

output "uri" {
  value       = azurerm_key_vault.this.vault_uri
  description = "Vault URI, exposed to env[].fromModule as keyvault.uri."
}

output "name" {
  value       = azurerm_key_vault.this.name
  description = "Vault name, exposed to env[].fromModule as keyvault.name."
}
