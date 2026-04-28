output "key_vault_id" {
  description = "ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = azurerm_key_vault.this.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "managed_identities" {
  description = "User-assigned managed identities by agent."
  value = {
    for agent, identity in azurerm_user_assigned_identity.agent :
    agent => {
      id           = identity.id
      client_id    = identity.client_id
      principal_id = identity.principal_id
      name         = identity.name
    }
  }
}
