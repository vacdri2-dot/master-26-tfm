resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days

  # UCM tenant lacks AMPLS; public ingestion + query lanes are forced. Access controlled via RBAC.
  internet_ingestion_enabled = true
  internet_query_enabled     = true

  tags = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "appi-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  workspace_id     = azurerm_log_analytics_workspace.this.id
  application_type = "web"

  daily_data_cap_in_gb = var.daily_cap_gb
  sampling_percentage  = var.sampling_percentage

  tags = var.tags
}
