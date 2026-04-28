output "subscription_id" {
  description = "Azure subscription ID used by this deployment."
  value       = var.subscription_id
}

output "location" {
  description = "Azure region used by this deployment."
  value       = var.location
}

output "environment" {
  description = "Deployment environment."
  value       = var.environment
}

output "project_name" {
  description = "Project name used for resource naming."
  value       = var.project_name
}

output "name_prefix" {
  description = "Computed resource naming prefix."
  value       = local.name_prefix
}

output "vnet_id" {
  description = "ID of the networking virtual network."
  value       = module.networking.vnet_id
}

output "subnet_ids" {
  description = "IDs of the networking subnets."
  value       = module.networking.subnet_ids
}

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs by service key."
  value       = module.networking.private_dns_zone_ids
}

output "private_dns_zone_names" {
  description = "Private DNS zone names by service key."
  value       = module.networking.private_dns_zone_names
}

output "private_endpoint_defaults" {
  description = "Base private endpoint configuration for other modules."
  value       = module.networking.private_endpoint_defaults
}

output "key_vault_id" {
  description = "ID of the Key Vault."
  value       = module.security.key_vault_id
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = module.security.key_vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = module.security.key_vault_name
}

output "managed_identities" {
  description = "User-assigned managed identities by agent."
  value       = module.security.managed_identities
}

output "acr_id" {
  description = "ID of the Azure Container Registry."
  value       = module.compute.acr_id
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = module.compute.acr_name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry."
  value       = module.compute.acr_login_server
}

output "container_app_environment_id" {
  description = "ID of the Container Apps Environment."
  value       = module.compute.container_app_environment_id
}

output "container_app_environment_name" {
  description = "Name of the Container Apps Environment."
  value       = module.compute.container_app_environment_name
}

output "container_app_environment_default_domain" {
  description = "Default domain of the Container Apps Environment."
  value       = module.compute.container_app_environment_default_domain
}

output "container_app_ids" {
  description = "Container App resource IDs by agent key."
  value       = module.compute.container_app_ids
}

output "container_app_names" {
  description = "Container App names by agent key."
  value       = module.compute.container_app_names
}

output "container_app_latest_revision_fqdns" {
  description = "Container App FQDNs by agent key."
  value       = module.compute.container_app_latest_revision_fqdns
}

output "openai_account_id" {
  description = "ID of the Azure OpenAI account."
  value       = module.ai.openai_id
}

output "openai_endpoint" {
  description = "Endpoint URL of the Azure OpenAI account."
  value       = module.ai.openai_endpoint
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace."
  value       = module.observability.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace."
  value       = module.observability.log_analytics_workspace_name
}

output "application_insights_id" {
  description = "ID of the Application Insights component."
  value       = module.observability.application_insights_id
}

output "application_insights_name" {
  description = "Name of the Application Insights component."
  value       = module.observability.application_insights_name
}

output "application_insights_connection_string" {
  description = "Connection String for Application Insights."
  value       = module.observability.application_insights_connection_string
  sensitive   = true
}

output "orchestrator_api_key" {
  description = "Bearer token expected by the orchestrator on POST /tasks. Read with `terraform output -raw orchestrator_api_key`."
  value       = random_password.orchestrator_api_key.result
  sensitive   = true
}

output "azure_monitor_workbook_id" {
  description = "Resource ID of the Azure Monitor workbook used for the demo dashboard."
  value       = module.dashboard.workbook_id
}

output "azure_monitor_workbook_name" {
  description = "Name of the Azure Monitor workbook used for the demo dashboard."
  value       = module.dashboard.workbook_name
}
