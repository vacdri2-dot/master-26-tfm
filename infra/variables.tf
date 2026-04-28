variable "subscription_id" {
  description = "Azure subscription ID where resources will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region for the deployment. Must support Azure OpenAI, Container Apps, and AI Search."
  type        = string
}

variable "allowed_locations" {
  description = "Optional whitelist of Azure regions. Null (default) accepts any region; set a list to enforce tenant-specific restrictions (e.g. Azure Policy)."
  type        = list(string)
  default     = null
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "project_name" {
  description = "Project identifier used for naming resources."
  type        = string
}

variable "resource_group_name" {
  description = "Shared resource group name for the environment."
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for the environment virtual network."
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "vnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "subnet_cidrs" {
  description = "CIDR blocks for the environment networking subnets."
  type = object({
    container_apps    = string
    private_endpoints = string
    data              = string
    langfuse          = string
  })

  validation {
    condition = alltrue([
      can(cidrhost(var.subnet_cidrs.container_apps, 0)),
      can(cidrhost(var.subnet_cidrs.private_endpoints, 0)),
      can(cidrhost(var.subnet_cidrs.data, 0)),
      can(cidrhost(var.subnet_cidrs.langfuse, 0)),
    ])
    error_message = "All subnet_cidrs values must be valid IPv4 CIDR blocks."
  }
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

variable "acr_admin_enabled" {
  description = "Whether ACR admin user is enabled. Keep false by default; toggle to true only for a one-off manual bootstrap."
  type        = bool
  default     = false
}

variable "agent_images" {
  description = "Optional per-agent image overrides for compute Container Apps."
  type = object({
    orchestrator = optional(string)
    rag          = optional(string)
    code         = optional(string)
  })
  default = {}
}

variable "agent_env_vars" {
  description = "Non-secret environment variables per agent (agent -> env key -> value)."
  type        = map(map(string))
  default     = {}
}

variable "agent_key_vault_env_secrets" {
  description = "Secret environment variables per agent using Key Vault secret IDs."
  type        = map(map(string))
  default     = {}
}

variable "agent_container_port" {
  description = "Container listening port exposed by all compute Container Apps."
  type        = number
  default     = 8000
}

variable "agent_min_replicas" {
  description = "Minimum replicas for each compute Container App."
  type        = number
  default     = 0
}

variable "agent_max_replicas" {
  description = "Maximum replicas for each compute Container App."
  type        = number
  default     = 3
}

variable "agent_cpu" {
  description = "vCPU allocation per agent container."
  type        = number
  default     = 0.5
}

variable "agent_memory" {
  description = "Memory allocation per agent container (Azure format, e.g. 1Gi)."
  type        = string
  default     = "1Gi"
}

variable "gpt4o_capacity" {
  description = "Tokens per minute capacity (thousands) for the GPT-4o deployment."
  type        = number
  default     = 10

  validation {
    condition     = var.gpt4o_capacity <= 40
    error_message = "gpt4o_capacity cannot exceed 40K TPM (subscription quota)."
  }
}

variable "embedding_capacity" {
  description = "Tokens per minute capacity (thousands) for the text-embedding-3-small deployment."
  type        = number
  default     = 10

  validation {
    condition     = var.embedding_capacity <= 120
    error_message = "embedding_capacity cannot exceed 120K TPM (subscription quota)."
  }
}

variable "openai_existing_account_id" {
  description = "Resource ID of a pre-existing Azure OpenAI account to adopt into state. Null to create a new one."
  type        = string
  default     = null
}

variable "openai_subdomain_suffix" {
  description = "Optional suffix appended to the OpenAI custom subdomain to avoid global collisions across tenants."
  type        = string
  default     = null
}

variable "acr_name_suffix" {
  description = "Optional suffix appended to the ACR name to avoid global collisions across tenants."
  type        = string
  default     = null
}
