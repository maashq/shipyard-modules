variable "name" {
  type        = string
  description = "Vault name. Globally unique across Azure, so it always carries a hash suffix (ADR-0020)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the vault."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "tenant_id" {
  type        = string
  description = "Entra tenant that owns the vault's RBAC."
}

variable "sku" {
  type        = string
  description = "\"standard\" or \"premium\", from modules.keyvault.sku."
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku)
    error_message = "Key Vault has two SKUs: standard and premium."
  }
}

variable "purge_protection" {
  type        = bool
  description = "Blocks permanent deletion during the soft-delete window. Cannot be turned off once on."
  default     = true
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Days a deleted vault stays recoverable."
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Azure accepts 7 to 90 days of soft-delete retention."
  }
}

variable "network_acls" {
  type = object({
    default_action             = string
    bypass                     = optional(string, "AzureServices")
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  description = "Vault firewall. Null leaves the data plane reachable from anywhere, with RBAC as the only gate. See the note in main.tf before changing the default."
  default     = null

  validation {
    condition     = var.network_acls == null || contains(["Allow", "Deny"], coalesce(try(var.network_acls.default_action, null), "Allow"))
    error_message = "default_action is Allow or Deny."
  }

  validation {
    condition     = var.network_acls == null || contains(["AzureServices", "None"], coalesce(try(var.network_acls.bypass, null), "AzureServices"))
    error_message = "bypass is AzureServices or None."
  }
}

variable "reader_principal_ids" {
  type        = list(string)
  description = "Principals granted Key Vault Secrets User. The app identities that read secrets, and nothing else."
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
