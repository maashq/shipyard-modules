# azure-identity

One user-assigned managed identity per project and environment. The Container
Apps use it to read Key Vault secrets and to pull from the registry.

## Why user-assigned and not system-assigned

A system-assigned identity does not exist until its Container App has been
created. But the app cannot be created with a `key_vault_secret_id` reference
unless some identity already holds read access on that vault. That is a cycle
within a single apply, and no ordering breaks it.

An identity that exists before both ends of the problem removes it rather than
working around it. ADR-0019.

## Usage

```hcl
module "identity" {
  source = "git::https://github.com/maashq/shipyard-modules.git//azure-identity?ref=v0.1.1"

  name                = "id-acme-invoice-api-prod"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
}
```

## Inputs

| Name                  | Type          | Default | Description                |
| --------------------- | ------------- | ------- | -------------------------- |
| `name`                | `string`      | —       | Identity name              |
| `resource_group_name` | `string`      | —       | Group holding the identity |
| `location`            | `string`      | —       | Azure region               |
| `tags`                | `map(string)` | `{}`    |                            |

## Outputs

| Name           | Used for                                                      |
| -------------- | ------------------------------------------------------------- |
| `id`           | attaching the identity to a Container App, and registry pulls |
| `principal_id` | role assignments, including the vault's Secrets User grant    |
| `client_id`    | selecting this identity from inside the running container     |
