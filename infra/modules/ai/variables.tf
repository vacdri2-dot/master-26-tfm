variable "location" {
  description = "Azure region where AI resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where AI resources will be created."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming AI resources."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where private endpoints will be created."
  type        = string
}

variable "openai_dns_zone_ids" {
  description = "Private DNS zone IDs for Azure OpenAI private endpoint."
  type        = list(string)
}

variable "gpt4o_capacity" {
  description = "Tokens per minute capacity (thousands) for the GPT-4o deployment."
  type        = number
  default     = 10
}

variable "embedding_capacity" {
  description = "Tokens per minute capacity (thousands) for the text-embedding-3-small deployment."
  type        = number
  default     = 10
}

variable "subdomain_suffix" {
  description = "Optional suffix appended to the OpenAI custom subdomain to avoid global collisions across tenants."
  type        = string
  default     = null
}

variable "tags" {
  description = "Shared tags applied to all taggable resources."
  type        = map(string)
}
