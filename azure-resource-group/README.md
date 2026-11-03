# azure-resource-group

The blast-radius boundary: one resource group per project and environment
(ADR-0004). Everything else in the environment is created inside it, so
deleting this group deletes that environment and nothing belonging to another.

## Why it is not part of `azure-environment`

M3-PLAN §3 put the group inside `azure-environment`. It cannot go there. The
workspace, the vault and the database all need the group before the managed
environment exists, while the managed environment needs the workspace. Owning
the group in `azure-environment` therefore places that module both before and
after `azure-loganalytics`, and Terraform rejects the graph:

```
Error: Cycle: module.logs (expand), module.environment (close),
  module.environment.var.log_analytics_workspace_id (expand),
  module.logs.output.workspace_id (expand), ...
```

ADR-0025 records the decision and the reproduction.

## Usage

```hcl
module "resource_group" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-resource-group?ref=v0.1.1"

  name     = "rg-acme-invoice-api-prod"
  location = "westeurope"
  tags     = { env = "prod" }
}
```

## Inputs

| Name       | Type          | Default | Description                       |
| ---------- | ------------- | ------- | --------------------------------- |
| `name`     | `string`      | —       | Group name, resolved at plan time |
| `location` | `string`      | —       | Azure region                      |
| `tags`     | `map(string)` | `{}`    | Applied to the group              |

## Outputs

`name`, `location`, `id`.
