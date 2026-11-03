# azure-containerapp

One Container App: the service itself, its scaling, its ingress, its probes and
its Key Vault references.

`revision_mode` is `"Multiple"` unconditionally (ADR-0007). Every deployment
strategy shipyard supports — all-at-once, canary and blue-green — is a traffic
shift between revisions, and rollback is the same operation pointed backwards.
Single mode cannot express any of them.

## `ignore_changes = [ingress[0].traffic_weight]`

Traffic weights are moved by the traffic-shift step of a run and by a rollback,
which are the two things Terraform must not undo. Without this, the next apply
drags a mid-flight canary back to its starting weights, or reverses a rollback
performed minutes earlier.

This is unconditional, where M3-PLAN §3 scoped it to canary and blue-green.
`ignore_changes` takes a static list — it cannot read a variable — so a
per-strategy version is not expressible in a module. The unconditional form is
also the correct one: a rollback is a traffic shift under every strategy,
all-at-once included. ADR-0024.

The consequence is that `var.traffic` is written once, on create, and is not
reconciled afterwards. The run owns the split from then on.

## CPU scaling

Container Apps has no first-class CPU scale rule. Azure's own answer is the
KEDA `cpu` scaler through `custom_scale_rule`, which is what the portal writes
too, so `cpu_scale_rules` renders:

```hcl
custom_scale_rule {
  name             = "cpu"
  custom_rule_type = "cpu"

  metadata = {
    type  = "Utilization"
    value = "70"
  }
}
```

## Secrets

`secrets` holds Key Vault references — a name and a `key_vault_secret_id` —
never values. `secret_identity_id` names the identity that reads them, and it
must already hold Key Vault Secrets User on the vault, which `azure-keyvault`
grants. Two preconditions enforce the wiring:

- secrets present but no `secret_identity_id` is an error, not a run-time 403
- an `env` entry pointing at a `secret_name` that is not in `secrets` is an
  error, rather than an app that starts with an empty variable

`env` entries carry either a `value` or a `secret_name`, never both and never
neither.

## Image

`image` is supplied per run through the root module's `image_digests` variable
(ADR-0022) and is never rendered into committed text. The committed
configuration describes the service; the digest describes one deployment of it.

## Usage

```hcl
module "app_api" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-containerapp?ref=v0.1.1"

  name                         = "invoice-api-prod"
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.environment.id

  identity_ids       = [module.identity.id]
  secret_identity_id = module.identity.id

  image  = var.image_digests["api"]
  cpu    = 0.5
  memory = "1Gi"

  ingress = { external = true, target_port = 8080 }

  http_scale_rules = [{ name = "http", concurrent_requests = 50 }]
  cpu_scale_rules  = [{ name = "cpu", utilization_percent = 70 }]

  probes = {
    liveness  = { path = "/healthz", port = 8080 }
    readiness = { path = "/readyz", port = 8080 }
  }

  secrets = [{
    name                = "db-connection-string"
    key_vault_secret_id = "${module.keyvault.uri}secrets/db-connection-string"
  }]

  env = [{ name = "DATABASE_URL", secret_name = "db-connection-string" }]

  registry = { server = "acme.azurecr.io", identity_id = module.identity.id }
}
```

## Inputs

| Name                            | Type                                             | Default                                        |
| ------------------------------- | ------------------------------------------------ | ---------------------------------------------- |
| `name`                          | `string`                                         | —                                              |
| `resource_group_name`           | `string`                                         | —                                              |
| `container_app_environment_id`  | `string`                                         | —                                              |
| `identity_ids`                  | `list(string)`                                   | `[]`                                           |
| `image`                         | `string`                                         | —                                              |
| `cpu`                           | `number`                                         | `0.5`                                          |
| `memory`                        | `string`                                         | `"1Gi"`                                        |
| `command` / `args`              | `list(string)`                                   | `[]`                                           |
| `min_replicas` / `max_replicas` | `number`                                         | `1` / `10`                                     |
| `http_scale_rules`              | `list(object({name, concurrent_requests}))`      | `[]`                                           |
| `cpu_scale_rules`               | `list(object({name, utilization_percent}))`      | `[]`                                           |
| `ingress`                       | `object({external, target_port})`                | `null` — reachable from nothing                |
| `traffic`                       | `list(object({percentage, latest_revision, …}))` | `[{percentage = 100, latest_revision = true}]` |
| `probes`                        | `map(object({path, port, …}))`                   | `{}`                                           |
| `env`                           | `list(object({name, value, secret_name}))`       | `[]`                                           |
| `secrets`                       | `list(object({name, key_vault_secret_id}))`      | `[]`                                           |
| `secret_identity_id`            | `string`                                         | `null`                                         |
| `registry`                      | `object({server, identity_id})`                  | `null` — public image                          |
| `max_inactive_revisions`        | `number`                                         | `10` — the rollback window depth               |
| `tags`                          | `map(string)`                                    | `{}`                                           |

Probe keys are `liveness`, `readiness` and `startup`; absent keys render no
probe, which Azure treats as always-ready. Traffic percentages must sum to 100.

## Outputs

`id`, `name`, `fqdn` (null without ingress), `latest_revision_name` — which the
traffic-shift step names when it moves weight — and `outbound_ip_addresses`.
