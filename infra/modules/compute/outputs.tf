output "acr_id" {
  description = "ID of the Azure Container Registry."
  value       = azurerm_container_registry.this.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.this.name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry."
  value       = azurerm_container_registry.this.login_server
}

output "container_app_environment_id" {
  description = "ID of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.id
}

output "container_app_environment_name" {
  description = "Name of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.name
}

output "container_app_environment_default_domain" {
  description = "Default domain of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.default_domain
}

output "container_app_ids" {
  description = "Container App resource IDs by agent key."
  value = {
    for agent, app in azurerm_container_app.agent :
    agent => app.id
  }
}

output "container_app_names" {
  description = "Container App names by agent key."
  value = {
    for agent, app in azurerm_container_app.agent :
    agent => app.name
  }
}

output "container_app_latest_revision_fqdns" {
  description = "Container App FQDNs by agent key."
  value = {
    for agent, app in azurerm_container_app.agent :
    agent => app.latest_revision_fqdn
  }
}
