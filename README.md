# Terraform modules

Every Azure resource shipyard creates is declared here, and nowhere else
(ADR-0002).

These modules are developed under `modules/` in the shipyard repository and
published, unchanged, to
[github.com/maashq/shipyard-modules](https://github.com/maashq/shipyard-modules)
at every release (ADR-0049). The public repository is a mirror: a release
replaces its contents, so a change made there directly does not survive the
next one. Licensed under Apache-2.0, see `LICENSE`.

References such as ADR-0002 point at shipyard's design records, which are not
public. Where a decision constrains a module, the reasoning is repeated next to
the code it constrains. The rendered root module in a customer's repository contains
`module` blocks and nothing but `module` blocks: no `resource`, no `data`, no
provider-specific expressions.

That is what makes the modules reviewable. A change to how a Container App is
built is a change to one file here, visible in one pull request, applied to
every project the next time its module ref moves. A generated root module full
of resources would have to be re-reviewed per project, per environment, forever.

## Versioning

Released as `vX.Y.Z` in the public repository, with the modules at its root.
In the shipyard repository the same release is the tag `modules/vX.Y.Z`, so
it cannot be confused with a control-plane tag there; pushing that tag is what
publishes it. A published tag is never moved, and the public repository
refuses an update to one. The rendered root module pins the tag:

```hcl
module "app_api" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-containerapp?ref=v0.1.1"
}
```

The first public release is `v0.1.1`. `v0.1.0` was only ever tagged in the
shipyard repository; `v0.1.1` is the same modules with this README and the
licence added.

The ref is data in the plan, not a constant in the emitter, so a project can
stay on an older module set while another moves ahead.

Semver applies to the module interface: a new optional variable is a minor, a
renamed or removed variable is a major, and so is a change that forces an
existing resource to be replaced.

## The modules

| Module                 | Creates                                                    | Rendered when                  |
| ---------------------- | ---------------------------------------------------------- | ------------------------------ |
| `azure-resource-group` | the resource group                                         | always                         |
| `azure-network`        | VNet, app subnet, Postgres subnet, private DNS zone + link | Postgres is private            |
| `azure-identity`       | user-assigned identity                                     | always                         |
| `azure-loganalytics`   | workspace                                                  | `modules.logAnalytics.enabled` |
| `azure-environment`    | Container Apps managed environment                         | always                         |
| `azure-keyvault`       | vault, RBAC assignments for the app identities             | `modules.keyvault.enabled`     |
| `azure-postgres`       | flexible server, databases, credential secrets             | `modules.postgres.enabled`     |
| `azure-containerapp`   | one Container App                                          | once per service               |

The resource group is its own module rather than part of `azure-environment`
(ADR-0025): the workspace, vault, network and database all need the group
before the managed environment exists, and the environment needs the
workspace, so a module owning both is a dependency cycle Terraform refuses.

## Rules these modules follow

- **No secret value is an input or an output.** A password is generated inside
  the module and written straight to Key Vault; what leaves the module is a
  secret _name_. `azure-postgres/main.tf` says more about what that does and
  does not protect.
- **No provider block, no backend block, no `required_providers` version
  ranges narrower than the root's.** A module that configures its own provider
  cannot be called twice with different subscriptions.
- **Every input is validated where Azure would otherwise reject it at apply
  time.** A `validation` block costs one plan; an apply-time rejection costs a
  half-finished environment.
- **Lifecycle rules protect what a run owns.** Traffic weights and failover
  zones are moved by a deployment, not by Terraform, and are ignored here so
  the next apply does not undo them.

## Scanning

`trivy config` runs over this directory, at HIGH and CRITICAL, as a test rather
than only as a CI step (ADR-0021), in the shipyard repository:
`packages/emitters/terraform/src/modules.test.ts`. It skips locally when trivy
is absent and fails in CI, so it cannot pass by not running.

Findings are fixed, not suppressed. Where a suppression is genuinely correct it
goes in `.trivyignore` with a reason and an `exp:` date that trivy enforces —
one entry today, AZU-0013 — and the reasoning is repeated next to the resource
it applies to. `trivy:ignore` comments in a module are not used: as of v0.74.0
trivy does not enforce the expiry on the inline form, so an expired inline
suppression outlives its own deadline in silence.

## Running them without shipyard

That is the point. Each module is a plain Terraform module: clone
`github.com/maashq/shipyard-modules`, `cd azure-keyvault`, `terraform init`,
and call it from whatever root module you like. Nothing here imports anything from the control
plane, and nothing here knows that shipyard exists.
