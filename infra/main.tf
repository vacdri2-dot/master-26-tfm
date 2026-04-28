data "azurerm_client_config" "current" {}

check "location_allowed" {
  assert {
    condition     = var.allowed_locations == null ? true : contains(var.allowed_locations, var.location)
    error_message = "var.location '${var.location}' is not in var.allowed_locations (${var.allowed_locations == null ? "null" : join(", ", var.allowed_locations)})."
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = {
    environment = var.environment
    project     = var.project_name
    managed-by  = "terraform"
  }
  default_agent_env_vars = {
    orchestrator = {
      AZURE_OPENAI_ENDPOINT        = module.ai.openai_endpoint
      AZURE_OPENAI_CHAT_DEPLOYMENT = module.ai.gpt4o_deployment_name
      AZURE_OPENAI_API_VERSION     = "2024-10-21"
      ORCHESTRATOR_REQUIRE_AUTH    = "true"
    }
    rag  = {}
    code = {}
  }
  merged_agent_env_vars = {
    for agent, env_vars in local.default_agent_env_vars :
    agent => merge(env_vars, lookup(var.agent_env_vars, agent, {}))
  }
  default_agent_value_secrets = {
    orchestrator = {
      APPLICATIONINSIGHTS_CONNECTION_STRING = module.observability.application_insights_connection_string
      ORCHESTRATOR_API_KEY                  = random_password.orchestrator_api_key.result
    }
    rag = {
      APPLICATIONINSIGHTS_CONNECTION_STRING = module.observability.application_insights_connection_string
    }
    code = {
      APPLICATIONINSIGHTS_CONNECTION_STRING = module.observability.application_insights_connection_string
    }
  }
}

resource "random_password" "orchestrator_api_key" {
  length  = 48
  special = false
}

module "networking" {
  source = "./modules/networking"

  location            = var.location
  resource_group_name = var.resource_group_name
  name_prefix         = local.name_prefix
  vnet_cidr           = var.vnet_cidr
  subnet_cidrs        = var.subnet_cidrs
  tags                = local.tags
}

module "security" {
  source = "./modules/security"

  location            = var.location
  resource_group_name = var.resource_group_name
  name_prefix         = local.name_prefix
  tenant_id           = data.azurerm_client_config.current.tenant_id

  private_endpoint_subnet_id = module.networking.private_endpoint_defaults.subnet_id
  key_vault_dns_zone_ids     = module.networking.private_endpoint_defaults.services.key_vault.private_dns_zone_ids
  storage_account_id         = var.storage_account_id
  ai_search_service_id       = var.ai_search_service_id
  openai_account_id          = module.ai.openai_id

  tags = local.tags
}

module "observability" {
  source = "./modules/observability"

  location            = var.location
  resource_group_name = var.resource_group_name
  name_prefix         = local.name_prefix

  retention_days      = 30
  daily_cap_gb        = 1
  sampling_percentage = 100

  tags = local.tags
}

module "compute" {
  source = "./modules/compute"

  location            = var.location
  resource_group_name = var.resource_group_name
  name_prefix         = local.name_prefix

  container_apps_subnet_id    = module.networking.subnet_ids["container-apps"]
  acr_name_suffix             = var.acr_name_suffix
  acr_admin_enabled           = var.acr_admin_enabled
  log_analytics_workspace_id  = module.observability.log_analytics_workspace_id
  managed_identities          = module.security.managed_identities
  agent_images                = var.agent_images
  agent_env_vars              = local.merged_agent_env_vars
  agent_key_vault_env_secrets = var.agent_key_vault_env_secrets
  agent_value_secrets         = local.default_agent_value_secrets
  agent_container_port        = var.agent_container_port
  agent_min_replicas          = var.agent_min_replicas
  agent_max_replicas          = var.agent_max_replicas
  agent_cpu                   = var.agent_cpu
  agent_memory                = var.agent_memory

  tags = local.tags

  depends_on = [module.security]
}

module "ai" {
  source = "./modules/ai"

  location            = var.location
  resource_group_name = var.resource_group_name
  name_prefix         = local.name_prefix

  private_endpoint_subnet_id = module.networking.private_endpoint_defaults.subnet_id
  openai_dns_zone_ids        = module.networking.private_endpoint_defaults.services.openai.private_dns_zone_ids

  gpt4o_capacity     = var.gpt4o_capacity
  embedding_capacity = var.embedding_capacity
  subdomain_suffix   = var.openai_subdomain_suffix

  tags = local.tags
}

module "dashboard" {
  source = "./modules/dashboard"

  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  container_app_ids          = module.compute.container_app_ids
  container_app_names        = module.compute.container_app_names

  tags = local.tags
}

import {
  for_each = var.openai_existing_account_id != null ? toset([var.openai_existing_account_id]) : toset([])
  to       = module.ai.azurerm_cognitive_account.openai
  id       = each.value
}

moved {
  from = module.compute.azurerm_log_analytics_workspace.this[0]
  to   = module.observability.azurerm_log_analytics_workspace.this
}
