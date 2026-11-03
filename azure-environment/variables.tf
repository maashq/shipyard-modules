variable "name" {
  type        = string
  description = "Managed environment name, resolved at plan time (ADR-0004)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the environment."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Workspace receiving console and system logs. Null sends logs nowhere, which is only reasonable when modules.logAnalytics is off."
  default     = null
}

variable "infrastructure_subnet_id" {
  type        = string
  description = "Delegated subnet for the environment. Set when Postgres is private, so the apps can reach it over the VNet."
  default     = null
}

variable "internal_load_balancer" {
  type        = bool
  description = "Keeps the environment's ingress inside the VNet. Requires infrastructure_subnet_id."
  default     = false
}

variable "zone_redundant" {
  type        = bool
  description = "Spreads the environment across availability zones. Requires infrastructure_subnet_id."
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
