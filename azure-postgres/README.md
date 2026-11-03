# azure-postgres

The PostgreSQL flexible server, its databases, and the two Key Vault secrets an
application needs to reach it.

## Where the administrator password lives

Nowhere a person types it, and nowhere shipyard stores it. Terraform generates
it with `random_password`, writes it straight into Key Vault, and the
application reads the connection string from that vault at run time. The spec,
the generated repository and the shipyard database hold the secret's _name_,
never its value.

The value does exist in Terraform state, which is unavoidable for any resource
Terraform creates with a password argument. That is precisely why ADR-0005 puts
state in a storage account with public access off, a delete lock and RBAC — the
state blob is a secret and is treated as one. Terraform 1.11 adds write-only
arguments (`administrator_password_wo`) that keep the value out of state
entirely; `policy.terraformVersion` is 1.9.8 today, so that is a change to make
when the floor moves, not a reason to hand-manage the password now.

Two secrets are written, not one:

| Secret                               | Content type        | Why                                                                        |
| ------------------------------------ | ------------------- | -------------------------------------------------------------------------- |
| `administrator_password_secret_name` | `password`          | for an operator connecting with `psql`                                     |
| `connection_string_secret_name`      | `connection-string` | for the app — assembling one from five variables gets `sslmode` wrong once |

The generated password is restricted to `-_=+*!` as its special characters. A
password containing `@` or `/` produces a connection string that parses as a
different host, and the failure surfaces at run time as a DNS error.

## Private access

Setting `delegated_subnet_id` gives the server no public endpoint at all,
rather than a public endpoint with a firewall in front of it. Azure requires
`private_dns_zone_id` alongside it and requires the public listener off; the
module sets `public_network_access_enabled` from the same condition and
declares a precondition for the zone. `azure-network` produces both values.

## SKU

`tier` and `sku` are separate inputs because Azure rejects mismatched pairs and
a single field hides which half is wrong. The module joins them:
`Burstable` + `Standard_B1ms` becomes `B_Standard_B1ms`.

Zone-redundant `high_availability` is unavailable on `Burstable`; that is a
precondition rather than an apply-time error.

## `ignore_changes`

Azure moves the server between availability zones on failover and writes the
new zone back. Without `ignore_changes = [zone,
high_availability[0].standby_availability_zone]` the next apply drags it back
to where it started, which is a failover in the opposite direction.

## Storage

`storage_gb` accepts the fixed set Azure allows and nothing else. Azure refuses
to shrink storage: scaling down replaces the server.

## Usage

```hcl
module "postgres" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-postgres?ref=v0.1.1"

  name                = "psql-invoice-api-prod-a1b2c3"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  tier       = "GeneralPurpose"
  sku        = "Standard_D2s_v3"
  storage_gb = 128
  databases  = ["invoices"]

  key_vault_id = module.keyvault.id

  delegated_subnet_id = module.network.postgres_subnet_id
  private_dns_zone_id = module.network.postgres_dns_zone_id
}
```

## Inputs

| Name                                 | Type           | Default                     | Description                                    |
| ------------------------------------ | -------------- | --------------------------- | ---------------------------------------------- |
| `name`                               | `string`       | —                           | Globally unique, hash suffix (ADR-0020)        |
| `resource_group_name`                | `string`       | —                           |                                                |
| `location`                           | `string`       | —                           |                                                |
| `postgres_version`                   | `string`       | `"16"`                      |                                                |
| `sku`                                | `string`       | `"Standard_B1ms"`           | Size half of the SKU name                      |
| `tier`                               | `string`       | `"Burstable"`               | `Burstable`/`GeneralPurpose`/`MemoryOptimized` |
| `storage_gb`                         | `number`       | `32`                        | Fixed set; cannot shrink                       |
| `backup_retention_days`              | `number`       | `7`                         | 7 to 35                                        |
| `geo_redundant_backup`               | `bool`         | `false`                     | Fixed at creation                              |
| `high_availability`                  | `bool`         | `false`                     | Not on Burstable                               |
| `databases`                          | `list(string)` | `["app"]`                   | First one goes into the connection string      |
| `administrator_login`                | `string`       | `"shipyard"`                | Not a secret                                   |
| `key_vault_id`                       | `string`       | —                           | Receives both secrets                          |
| `administrator_password_secret_name` | `string`       | `"postgres-admin-password"` |                                                |
| `connection_string_secret_name`      | `string`       | `"db-connection-string"`    | What `env[].fromKeyVault` points at            |
| `delegated_subnet_id`                | `string`       | `null`                      | Set for private access                         |
| `private_dns_zone_id`                | `string`       | `null`                      | Required with the subnet                       |
| `tags`                               | `map(string)`  | `{}`                        |                                                |

Writing the secrets requires the deploying principal to hold **Key Vault
Secrets Officer** on the vault. The app identity holds Secrets User and can
only read them.

## Outputs

`host`, `port`, `database`, `username`, `connection_string_secret` and
`server_id`. The first five are the `MODULE_OUTPUTS.postgres` set that
`env[].fromModule` can reference. `connection_string_secret` is the secret's
**name**; no output of this module is a secret value.
