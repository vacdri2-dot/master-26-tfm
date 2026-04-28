variable "location" {
  description = "Azure region where security resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where security resources will be created."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming security resources."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID for Key Vault."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where private endpoints will be created."
  type        = string
}

variable "key_vault_dns_zone_ids" {
  description = "Private DNS zone IDs for Key Vault private endpoint."
  type        = list(string)
}

variable "storage_account_id" {
  description = "Storage account resource ID used for RBAC assignments."
  type        = string
  default     = null
}

variable "ai_search_service_id" {
  description = "Azure AI Search service resource ID used for RBAC assignments."
  type        = string
  default     = null
}

variable "openai_account_id" {
  description = "Azure OpenAI account resource ID used for RBAC assignments."
  type        = string
  default     = null
}

variable "tags" {
  description = "Shared tags applied to all taggable resources."
  type        = map(string)
}
