variable "name" {
  type        = string
  description = "Server name. Globally unique across Azure, so it always carries a hash suffix (ADR-0020)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the server."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "postgres_version" {
  type        = string
  description = "Major version, from modules.postgres.version."
  default     = "16"
}

variable "sku" {
  type        = string
  description = "Flexible server SKU, e.g. \"Standard_B1ms\". Combined with tier below."
  default     = "Standard_B1ms"
}

variable "tier" {
  type        = string
  description = "Burstable, GeneralPurpose or MemoryOptimized."
  default     = "Burstable"

  validation {
    condition     = contains(["Burstable", "GeneralPurpose", "MemoryOptimized"], var.tier)
    error_message = "Tier is Burstable, GeneralPurpose or MemoryOptimized."
  }
}

variable "storage_gb" {
  type        = number
  description = "Storage in GB. Azure accepts a fixed set of sizes and refuses to shrink one: scaling down replaces the server."
  default     = 32

  validation {
    condition     = contains([32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768], var.storage_gb)
    error_message = "Azure accepts 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384 or 32768 GB."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "Days of point-in-time restore, from modules.postgres.backupRetentionDays."
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "Azure accepts 7 to 35 days of backup retention."
  }
}

variable "geo_redundant_backup" {
  type        = bool
  description = "Replicates backups to the paired region. Fixed at creation."
  default     = false
}

variable "high_availability" {
  type        = bool
  description = "Zone-redundant standby. Doubles the cost and is unavailable on Burstable."
  default     = false
}

variable "databases" {
  type        = list(string)
  description = "Databases created on the server."
  default     = ["app"]
}

variable "administrator_login" {
  type        = string
  description = "Admin username. Not a secret: the password lives in Key Vault and is never rendered here."
  default     = "shipyard"
}

variable "key_vault_id" {
  type        = string
  description = "Vault receiving the generated password and connection string. The values are written here and read from here; nothing else ever holds them."
}

variable "administrator_password_secret_name" {
  type        = string
  description = "Secret name for the generated administrator password."
  default     = "postgres-admin-password"
}

variable "connection_string_secret_name" {
  type        = string
  description = "Secret name for the full connection string, which env[].fromKeyVault points at."
  default     = "db-connection-string"
}

variable "delegated_subnet_id" {
  type        = string
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers. Set for private access."
  default     = null
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS zone resolving the server FQDN inside the VNet. Required with delegated_subnet_id."
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
