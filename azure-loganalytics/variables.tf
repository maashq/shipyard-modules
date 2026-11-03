variable "name" {
  type        = string
  description = "Workspace name, resolved at plan time (ADR-0004)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the workspace."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "retention_days" {
  type        = number
  description = "Log retention, from modules.logAnalytics.retentionDays."
  default     = 30

  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "Azure accepts 30 to 730 days of retention."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
