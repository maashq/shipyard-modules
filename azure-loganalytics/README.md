# azure-loganalytics

The workspace the Container Apps environment sends console output and system
logs to. Rendered when `modules.logAnalytics.enabled` is true, which normalize
resolves to true unless it is explicitly turned off — a Container App whose
logs go nowhere cannot be supported.

`PerGB2018` is fixed rather than exposed: it is the only SKU Azure still opens
to new workspaces, and the older tiers are rejected at creation.

## Usage

```hcl
module "logs" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-loganalytics?ref=v0.1.1"

  name                = "log-acme-invoice-api-prod"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  retention_days      = 30
}
```

## Inputs

| Name                  | Type          | Default | Description                               |
| --------------------- | ------------- | ------- | ----------------------------------------- |
| `name`                | `string`      | —       | Workspace name                            |
| `resource_group_name` | `string`      | —       | Group holding the workspace               |
| `location`            | `string`      | —       | Azure region                              |
| `retention_days`      | `number`      | `30`    | 30 to 730; Azure rejects anything outside |
| `tags`                | `map(string)` | `{}`    |                                           |

## Outputs

| Name           | Description                                      |
| -------------- | ------------------------------------------------ |
| `workspace_id` | resource id, consumed by the managed environment |
| `customer_id`  | workspace GUID, which queries and dashboards use |

`customer_id` is exposed to `env[].fromModule` as `logAnalytics.customerId`,
and `workspace_id` as `logAnalytics.workspaceId`.
