variable "name" {
  type        = string
  description = "Virtual network name, resolved at plan time (ADR-0004). Subnets and the DNS link derive their names from it."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the network."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "address_space" {
  type        = list(string)
  description = "VNet address space. The default is private and large enough for every subnet below."
  default     = ["10.0.0.0/16"]
}

variable "apps_subnet_prefix" {
  type        = string
  description = "Subnet for the Container Apps environment. Azure requires /27 or larger for a workload profiles environment; the default is /23 so the legacy environment type would also fit."
  default     = "10.0.0.0/23"
}

variable "postgres_enabled" {
  type        = bool
  description = "Creates the delegated Postgres subnet, the private DNS zone and its link. Set when modules.postgres.privateAccess is on."
  default     = false
}

variable "postgres_subnet_prefix" {
  type        = string
  description = "Subnet for the flexible server. Azure requires it to hold nothing else."
  default     = "10.0.2.0/24"
}

variable "postgres_dns_zone_name" {
  type        = string
  description = "Private DNS zone resolving the server FQDN. Azure requires the .postgres.database.azure.com suffix."
  default     = null

  validation {
    condition     = var.postgres_dns_zone_name == null || endswith(coalesce(var.postgres_dns_zone_name, "x"), ".postgres.database.azure.com")
    error_message = "A Postgres private DNS zone name has to end with \".postgres.database.azure.com\"."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
