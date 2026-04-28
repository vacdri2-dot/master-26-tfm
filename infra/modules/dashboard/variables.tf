variable "location" {
  description = "Azure region where the workbook is created."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where the workbook is created."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID used as workbook context."
  type        = string
}

variable "container_app_ids" {
  description = "Container App resource IDs by agent key."
  type        = map(string)
}

variable "container_app_names" {
  description = "Container App names by agent key."
  type        = map(string)
}

variable "tags" {
  description = "Shared tags applied to the workbook."
  type        = map(string)
}
