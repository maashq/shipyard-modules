variable "name" {
  type        = string
  description = "Identity name, resolved at plan time (ADR-0004)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the identity."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "tags" {
  type    = map(string)
  default = {}
}
