# azure-network

The virtual network, present only when something in the environment needs to be
private. A project with a public database and a public-ingress app never
renders this module at all.

Its own module rather than part of `azure-environment`: the managed environment
and the database each take one subnet from it, and neither owns the other.

## What it creates

Always: the VNet and the apps subnet, delegated to `Microsoft.App/environments`.

Behind `postgres_enabled`: a second subnet delegated to
`Microsoft.DBforPostgreSQL/flexibleServers`, the private DNS zone, and the link
between the zone and the VNet. Without the link the zone exists but nothing in
the VNet resolves against it, and the app gets a hostname it cannot look up.

## Delegation is not symmetric

| Environment type  | Apps subnet delegation       | Minimum size |
| ----------------- | ---------------------------- | ------------ |
| Workload profiles | `Microsoft.App/environments` | `/27`        |
| Consumption-only  | none                         | `/23`        |

`azure-environment` creates the workload profiles type, so this module always
delegates. The default `/23` is larger than required so the same address plan
would also fit the legacy type.

Azure requires the Postgres subnet to hold nothing but the flexible server, so
it is never shared with the apps subnet.

## Usage

```hcl
module "network" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-network?ref=v0.1.1"

  name                = "vnet-invoice-api-prod"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  postgres_enabled       = true
  postgres_dns_zone_name = "invoice-api-prod.postgres.database.azure.com"
}
```

## Inputs

| Name                     | Type           | Default           | Description                                 |
| ------------------------ | -------------- | ----------------- | ------------------------------------------- |
| `name`                   | `string`       | —                 | Subnets and the DNS link derive their names |
| `resource_group_name`    | `string`       | —                 |                                             |
| `location`               | `string`       | —                 |                                             |
| `address_space`          | `list(string)` | `["10.0.0.0/16"]` |                                             |
| `apps_subnet_prefix`     | `string`       | `"10.0.0.0/23"`   |                                             |
| `postgres_enabled`       | `bool`         | `false`           | From `modules.postgres.privateAccess`       |
| `postgres_subnet_prefix` | `string`       | `"10.0.2.0/24"`   |                                             |
| `postgres_dns_zone_name` | `string`       | `null`            | Must end `.postgres.database.azure.com`     |
| `tags`                   | `map(string)`  | `{}`              |                                             |

## Outputs

`vnet_id`, `apps_subnet_id`, `postgres_subnet_id`, `postgres_dns_zone_id`. The
last two are `null` when `postgres_enabled` is false.
