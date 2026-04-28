locals {
  agent_names = toset([
    "orchestrator",
    "rag",
    "code",
  ])
}

resource "azurerm_key_vault" "this" {
  name                = "kv-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  rbac_authorization_enabled = true

  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "agent" {
  for_each = local.agent_names

  name                = "id-${each.key}-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-kv-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-kv-${var.name_prefix}"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "dns-kv-${var.name_prefix}"
    private_dns_zone_ids = var.key_vault_dns_zone_ids
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  for_each = azurerm_user_assigned_identity.agent

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}

# RBAC assignments are skipped (for_each = {}) when the target module's ID is null.
resource "azurerm_role_assignment" "openai_user" {
  for_each = var.openai_account_id == null ? {} : azurerm_user_assigned_identity.agent

  scope                = var.openai_account_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  for_each = var.storage_account_id == null ? {} : {
    code = azurerm_user_assigned_identity.agent["code"]
  }

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "storage_blob_data_reader" {
  for_each = var.storage_account_id == null ? {} : {
    rag = azurerm_user_assigned_identity.agent["rag"]
  }

  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "search_index_data_reader" {
  for_each = var.ai_search_service_id == null ? {} : {
    rag = azurerm_user_assigned_identity.agent["rag"]
  }

  scope                = var.ai_search_service_id
  role_definition_name = "Search Index Data Reader"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}
