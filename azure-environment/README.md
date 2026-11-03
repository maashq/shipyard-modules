# azure-environment

The Container Apps managed environment: the shared network and logging boundary
every app in one project and environment runs inside.

It does **not** own the resource group. The workspace, the vault and the
database all need that group before this environment exists, so owning it here
would place this module both before and after `azure-loganalytics` — a cycle
Terraform rejects at validate time. See `modules/azure-resource-group` and
ADR-0025.

## The subnet asymmetry

If `infrastructure_subnet_id` is set, the subnet must be delegated to
`Microsoft.App/environments` and be `/27` or larger. That is true for the
workload profiles environment, which is what this module creates and what Azure
defaults to. The legacy Consumption-only environment requires the exact
opposite — no delegation, and `/23` or larger. Getting it wrong is an
apply-time failure, not a plan-time one, which is why `azure-network` renders
the delegation and this module never guesses.

## Preconditions

Both `internal_load_balancer` and `zone_redundant` require
`infrastructure_subnet_id`, and both are fixed at creation. Changing either
replaces the environment, taking every app in it down and giving them new
FQDNs. Terraform would do that without comment; the preconditions turn it into
an error naming what has to happen instead.

## Usage

```hcl
module "environment" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-environment?ref=v0.1.1"

  name                = "cae-invoice-api-prod"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  log_analytics_workspace_id = module.logs.workspace_id
  infrastructure_subnet_id   = module.network.apps_subnet_id
}
```

## Inputs

| Name                         | Type          | Default | Description                                         |
| ---------------------------- | ------------- | ------- | --------------------------------------------------- |
| `name`                       | `string`      | —       |                                                     |
| `resource_group_name`        | `string`      | —       |                                                     |
| `location`                   | `string`      | —       |                                                     |
| `log_analytics_workspace_id` | `string`      | `null`  | Null sends logs nowhere                             |
| `infrastructure_subnet_id`   | `string`      | `null`  | Delegated subnet; set when anything must be private |
| `internal_load_balancer`     | `bool`        | `false` | Requires the subnet                                 |
| `zone_redundant`             | `bool`        | `false` | Requires the subnet                                 |
| `tags`                       | `map(string)` | `{}`    |                                                     |

## Outputs

`id`, `default_domain`, `static_ip_address`.
