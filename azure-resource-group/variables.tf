variable "name" {
  type        = string
  description = "Resource group name, resolved at plan time (ADR-0004)."
}

variable "location" {
  type        = string
  description = "Azure region, e.g. \"westeurope\"."
}

variable "tags" {
  type        = map(string)
  description = "Applied to the group and inherited by convention, not by Azure."
  default     = {}
}
