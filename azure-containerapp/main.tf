# One Container App, always in multi-revision mode (ADR-0007).
#
# Multi-revision is what makes canary, blue-green and rollback the same
# mechanism with different weights over time. A single-revision app can only be
# rolled back by deploying the previous image again, which is a build, not a
# rollback.
resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Multiple"
  max_inactive_revisions       = var.max_inactive_revisions
  tags                         = var.tags

  # A system-assigned identity is created with the app; a user-assigned one
  # exists before it. Both can be attached at once, which is what an app
  # wanting a system principal while still reading vault secrets needs.
  dynamic "identity" {
    for_each = length(var.identity_ids) > 0 || var.system_identity ? [1] : []

    content {
      type = (
        length(var.identity_ids) == 0 ? "SystemAssigned" :
        var.system_identity ? "SystemAssigned, UserAssigned" : "UserAssigned"
      )
      identity_ids = var.identity_ids
    }
  }

  # A reference to a vault secret, resolved by the app at start-up using the
  # identity below. The value is never in this file, in state, or in the
  # shipyard database.
  dynamic "secret" {
    for_each = { for s in var.secrets : s.name => s }

    content {
      name                = secret.value.name
      key_vault_secret_id = secret.value.key_vault_secret_id
      identity            = var.secret_identity_id
    }
  }

  dynamic "registry" {
    for_each = var.registry == null ? [] : [var.registry]

    content {
      server   = registry.value.server
      identity = registry.value.identity_id
    }
  }

  dynamic "ingress" {
    for_each = var.ingress == null ? [] : [var.ingress]

    content {
      external_enabled = ingress.value.external
      target_port      = ingress.value.target_port
      transport        = "auto"

      dynamic "traffic_weight" {
        for_each = var.traffic

        content {
          percentage      = traffic_weight.value.percentage
          latest_revision = traffic_weight.value.latest_revision
          revision_suffix = traffic_weight.value.revision_suffix
          label           = traffic_weight.value.label
        }
      }
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    dynamic "http_scale_rule" {
      for_each = { for r in var.http_scale_rules : r.name => r }

      content {
        name                = http_scale_rule.value.name
        concurrent_requests = tostring(http_scale_rule.value.concurrent_requests)
      }
    }

    # Container Apps has no first-class CPU rule. Azure's own answer is the
    # KEDA cpu scaler through custom_scale_rule, which is what the portal
    # writes too.
    dynamic "custom_scale_rule" {
      for_each = { for r in var.cpu_scale_rules : r.name => r }

      content {
        name             = custom_scale_rule.value.name
        custom_rule_type = "cpu"

        metadata = {
          type  = "Utilization"
          value = tostring(custom_scale_rule.value.utilization_percent)
        }
      }
    }

    container {
      name   = var.name
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      command = var.command
      args    = var.args

      dynamic "env" {
        for_each = var.env

        content {
          name        = env.value.name
          value       = env.value.value
          secret_name = env.value.secret_name
        }
      }

      dynamic "liveness_probe" {
        for_each = contains(keys(var.probes), "liveness") ? [var.probes["liveness"]] : []

        content {
          transport               = "HTTP"
          path                    = liveness_probe.value.path
          port                    = liveness_probe.value.port
          initial_delay           = liveness_probe.value.initial_delay
          interval_seconds        = liveness_probe.value.interval_seconds
          timeout                 = liveness_probe.value.timeout
          failure_count_threshold = liveness_probe.value.failure_count_threshold
        }
      }

      dynamic "readiness_probe" {
        for_each = contains(keys(var.probes), "readiness") ? [var.probes["readiness"]] : []

        content {
          transport               = "HTTP"
          path                    = readiness_probe.value.path
          port                    = readiness_probe.value.port
          initial_delay           = readiness_probe.value.initial_delay
          interval_seconds        = readiness_probe.value.interval_seconds
          timeout                 = readiness_probe.value.timeout
          failure_count_threshold = readiness_probe.value.failure_count_threshold
        }
      }

      dynamic "startup_probe" {
        for_each = contains(keys(var.probes), "startup") ? [var.probes["startup"]] : []

        content {
          transport               = "HTTP"
          path                    = startup_probe.value.path
          port                    = startup_probe.value.port
          initial_delay           = startup_probe.value.initial_delay
          interval_seconds        = startup_probe.value.interval_seconds
          timeout                 = startup_probe.value.timeout
          failure_count_threshold = startup_probe.value.failure_count_threshold
        }
      }
    }
  }

  lifecycle {
    # Traffic weights are moved by the traffic-shift step of a run, and by a
    # rollback, which are the two things Terraform must not undo. Without this
    # the next apply drags a mid-flight canary back to its starting weights,
    # or reverses a rollback that was performed minutes earlier.
    #
    # Unconditional, unlike M3-PLAN §3, which scoped it to canary and
    # blue-green. `ignore_changes` takes a static list: it cannot read a
    # variable, so a per-strategy version is not expressible in a module. The
    # unconditional form is also the correct one — a rollback is a traffic
    # shift under every strategy, all-at-once included. ADR-0024.
    ignore_changes = [ingress[0].traffic_weight]

    precondition {
      condition     = length(var.secrets) == 0 || var.secret_identity_id != null
      error_message = "Reading a Key Vault secret needs an identity: set secret_identity_id to a user-assigned identity holding Key Vault Secrets User on the vault."
    }

    precondition {
      # A system-assigned principal does not exist until this resource has been
      # created, so it cannot hold Key Vault Secrets User while Azure resolves
      # the secret reference during that same creation (ADR-0019).
      condition     = length(var.secrets) == 0 || var.secret_identity_id != "System"
      error_message = "A system-assigned identity cannot read a Key Vault secret on the apply that creates the app. Attach a user-assigned identity instead."
    }

    precondition {
      condition     = length(var.env) == 0 || alltrue([for e in var.env : e.secret_name == null || contains([for s in var.secrets : s.name], e.secret_name)])
      error_message = "An environment variable points at a secret_name that is not in secrets."
    }
  }
}
