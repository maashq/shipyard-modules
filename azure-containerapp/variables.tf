variable "name" {
  type        = string
  description = "Container App name, resolved at plan time (ADR-0004). Azure caps this at 32 characters."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the app."
}

variable "container_app_environment_id" {
  type        = string
  description = "Managed environment the app runs in. Fixes its region and its network."
}

variable "identity_ids" {
  type        = list(string)
  description = "User-assigned identities attached to the app. Empty with system_identity false means no identity at all, which is only viable for a service that reads no secrets and pulls from a public registry (ADR-0019)."
  default     = []
}

variable "system_identity" {
  type        = bool
  description = "Attach a system-assigned identity, created with the app and deleted with it. It cannot hold a role before the app exists, so it cannot read a Key Vault secret on the first apply (ADR-0019); a registry pull is granted afterwards and retried, which is why this is viable for an app with no secrets."
  default     = false
}

variable "image" {
  type        = string
  description = "Fully qualified image reference, pinned by digest. Supplied per run through the root module's image_digests variable (ADR-0022), never rendered into committed text."
}

variable "cpu" {
  type        = number
  description = "vCPU, from runtime.resources.cpu. Azure accepts only specific cpu and memory pairs; the spec checks the pairing."
  default     = 0.5
}

variable "memory" {
  type        = string
  description = "Memory with a Gi suffix, from runtime.resources.memory."
  default     = "1Gi"
}

variable "command" {
  type        = list(string)
  description = "Overrides the image entrypoint. Empty keeps the Dockerfile's."
  default     = []
}

variable "args" {
  type        = list(string)
  description = "Arguments appended to the entrypoint."
  default     = []
}

variable "min_replicas" {
  type        = number
  description = "Zero allows scale to zero, at the cost of a cold start."
  default     = 1
}

variable "max_replicas" {
  type    = number
  default = 10
}

variable "http_scale_rules" {
  type = list(object({
    name                = string
    concurrent_requests = number
  }))
  description = "Scale on in-flight HTTP requests per replica."
  default     = []
}

variable "cpu_scale_rules" {
  type = list(object({
    name                = string
    utilization_percent = number
  }))
  description = "Scale on CPU utilisation. Rendered as a KEDA cpu rule, which Container Apps exposes only through custom_scale_rule."
  default     = []
}

variable "ingress" {
  type = object({
    external    = bool
    target_port = number
  })
  description = "Null means no ingress at all: the app is reachable from nothing, not even from inside the environment."
  default     = null
}

variable "traffic" {
  type = list(object({
    percentage      = number
    latest_revision = optional(bool, false)
    revision_suffix = optional(string)
    label           = optional(string)
  }))
  description = "Traffic split written on create. Terraform stops managing it afterwards; see the lifecycle block in main.tf."
  default     = [{ percentage = 100, latest_revision = true }]

  validation {
    condition     = length(var.traffic) == 0 || sum([for t in var.traffic : t.percentage]) == 100
    error_message = "Traffic weights have to add up to 100."
  }
}

variable "probes" {
  type = map(object({
    path                    = string
    port                    = number
    initial_delay           = optional(number, 0)
    interval_seconds        = optional(number, 10)
    timeout                 = optional(number, 1)
    failure_count_threshold = optional(number, 3)
  }))
  description = "Keyed \"liveness\", \"readiness\" or \"startup\". Absent keys render no probe, which is what Azure treats as always-ready."
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.probes) : contains(["liveness", "readiness", "startup"], k)])
    error_message = "Probe keys are liveness, readiness and startup."
  }
}

variable "env" {
  type = list(object({
    name        = string
    value       = optional(string)
    secret_name = optional(string)
  }))
  description = "Environment variables in spec order. A value is a literal; a secret_name points at an entry in secrets below and is what a Key Vault reference becomes."
  default     = []

  validation {
    condition     = alltrue([for e in var.env : (e.value == null) != (e.secret_name == null)])
    error_message = "Each environment variable carries either a value or a secret_name, never both and never neither."
  }
}

variable "secrets" {
  type = list(object({
    name                = string
    key_vault_secret_id = string
  }))
  description = "Key Vault references, never values. The app reads them at start-up with the identity below; nothing here is a secret at rest."
  default     = []
}

variable "secret_identity_id" {
  type        = string
  description = "Identity used to read the secrets above. Must already hold Key Vault Secrets User on the vault, which is why azure-keyvault grants it rather than this module."
  default     = null
}

variable "registry" {
  type = object({
    server      = string
    identity_id = string
  })
  description = "Private registry and the identity that pulls from it. Null means the image is public."
  default     = null
}

variable "max_inactive_revisions" {
  type        = number
  description = "Inactive revisions kept for rollback. Rolling back is a traffic shift to one of these (ADR-0007), so this is the depth of the rollback window."
  default     = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
