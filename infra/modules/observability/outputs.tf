output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace. Pass to compute module to avoid duplicate workspace creation."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "application_insights_id" {
  description = "ID of the Application Insights component."
  value       = azurerm_application_insights.this.id
}

output "application_insights_name" {
  description = "Name of the Application Insights component."
  value       = azurerm_application_insights.this.name
}

output "application_insights_connection_string" {
  description = "Connection String for Application Insights. Store in Key Vault - do not hardcode in application config."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}
