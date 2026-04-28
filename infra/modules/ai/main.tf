locals {
  openai_name      = "oai-${var.name_prefix}"
  openai_subdomain = var.subdomain_suffix != null ? "${local.openai_name}-${var.subdomain_suffix}" : local.openai_name
}

resource "azurerm_cognitive_account" "openai" {
  name                = local.openai_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "OpenAI"
  sku_name            = "S0"

  custom_subdomain_name = local.openai_subdomain

  public_network_access_enabled = false

  tags = var.tags
}

resource "azurerm_private_endpoint" "openai" {
  name                = "pe-oai-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-oai-${var.name_prefix}"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "dns-oai-${var.name_prefix}"
    private_dns_zone_ids = var.openai_dns_zone_ids
  }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }

  # text-embedding-3-small is not available with `Standard` in swedencentral; both deployments use the same SKU for consistency.
  sku {
    name     = "DataZoneStandard"
    capacity = var.gpt4o_capacity
  }

  # Azure assigns rai_policy_name automatically; provider would otherwise show drift on every plan.
  lifecycle {
    ignore_changes = [rai_policy_name]
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = "text-embedding-3-small"
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-small"
    version = "1"
  }

  sku {
    name     = "DataZoneStandard"
    capacity = var.embedding_capacity
  }

  lifecycle {
    ignore_changes = [rai_policy_name]
  }
}
