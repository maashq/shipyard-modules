# azure-keyvault

The one place a secret value exists. The spec, the generated repository and the
shipyard database hold references — a vault name and a secret name — and never
a value.

## RBAC, not access policies

`rbac_authorization_enabled = true` is fixed rather than exposed. Access
policies are per-vault ACLs that no subscription-wide review can see, and Azure
now treats them as legacy. Every grant this module makes is a role assignment
that shows up in the same place as every other role assignment in the
subscription.

Readers get **Key Vault Secrets User**, not Secrets Officer. Reading a secret
is what an app does; writing one is an operator action that should not ride on
a deployment.

## Why the firewall is open by default

`trivy` raises AZU-0013 on a vault without a deny-by-default network ACL, and
it is right about the general case. It is not something this module can default
to, because two things that must reach the vault sit outside any network we
control:

- Terraform writes the generated Postgres credentials here, from a
  GitHub-hosted runner or from the direct executor. Neither has a stable
  address, and GitHub's published runner ranges are too large to be a
  meaningful allowlist.
- Container Apps resolves a secret reference at revision start-up. It is not on
  Key Vault's trusted-services list, so `bypass = "AzureServices"` does not
  cover it; closing the vault stops apps from starting.

Deny-by-default therefore needs a private endpoint and a vault-scoped subnet,
which is separate work with its own cost. Until then the gate is RBAC, and
`network_acls` is here so an operator who has done that work can close the
vault without editing this module. The finding is suppressed in `main.tf` with
a `trivy:ignore` comment carrying the same reasoning.

## Why the role assignment lives here and not in `azure-containerapp`

The assignment has to exist before the Container App is created, or the app's
`secret` block cannot resolve its `key_vault_secret_id` on the first apply. The
vault module owns the grant, so the app module only has to be ordered after it.

## Usage

```hcl
module "keyvault" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-keyvault?ref=v0.1.1"

  name                = "kv-invoice-api-prod-a1b2c3"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tenant_id           = data.azurerm_client_config.current.tenant_id

  reader_principal_ids = [module.identity.principal_id]
}
```

## Inputs

| Name                         | Type           | Default      | Description                                             |
| ---------------------------- | -------------- | ------------ | ------------------------------------------------------- |
| `name`                       | `string`       | —            | Globally unique, so it carries a hash suffix (ADR-0020) |
| `resource_group_name`        | `string`       | —            |                                                         |
| `location`                   | `string`       | —            |                                                         |
| `tenant_id`                  | `string`       | —            | Entra tenant owning the vault's RBAC                    |
| `sku`                        | `string`       | `"standard"` | `standard` or `premium`                                 |
| `purge_protection`           | `bool`         | `true`       | Cannot be turned off once on                            |
| `soft_delete_retention_days` | `number`       | `90`         | 7 to 90                                                 |
| `network_acls`               | `object(…)`    | `null`       | Vault firewall; see above                               |
| `reader_principal_ids`       | `list(string)` | `[]`         | Granted Key Vault Secrets User                          |
| `tags`                       | `map(string)`  | `{}`         |                                                         |

`purge_protection` defaults on and is irreversible in Azure. A vault created
with it cannot be permanently deleted before the retention window expires, so a
destroyed environment leaves its vault name reserved until then. That is the
intended trade: recovering a deleted production secret beats reusing a name.

## Outputs

`id`, `uri` (`keyvault.uri` in `env[].fromModule`), `name` (`keyvault.name`).
