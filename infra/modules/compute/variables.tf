variable "location" {
  description = "Azure region where compute resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where compute resources will be created."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming compute resources."
  type        = string
}

variable "container_apps_subnet_id" {
  description = "Subnet ID dedicated to the Container Apps Environment."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID (sourced from observability module) for Container Apps Environment."
  type        = string
}

variable "acr_admin_enabled" {
  description = "Whether ACR admin user is enabled. Keep false by default; toggle to true only for a one-off manual bootstrap."
  type        = bool
  default     = false
}

variable "managed_identities" {
  description = "User-assigned managed identities by agent key (orchestrator, rag, code)."
  type = map(object({
    id           = string
    client_id    = string
    principal_id = string
    name         = string
  }))

  validation {
    condition = alltrue([
      contains(keys(var.managed_identities), "orchestrator"),
      contains(keys(var.managed_identities), "rag"),
      contains(keys(var.managed_identities), "code"),
    ])
    error_message = "managed_identities must include orchestrator, rag, and code."
  }
}

variable "agent_images" {
  description = "Optional per-agent container image overrides."
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
  description = "Secret environment variables per agent backed by Key Vault references (agent -> env key -> Key Vault secret ID)."
  type        = map(map(string))
  default     = {}
}

variable "agent_value_secrets" {
  description = "Secret environment variables per agent stored as Container Apps value secrets, encrypted at rest by the platform without Key Vault round-trip (agent -> env key -> raw value). Use for values that do not need to live in Key Vault — e.g. App Insights connection string when the Key Vault is private and unreachable from CI."
  type        = map(map(string))
  default     = {}
  sensitive   = true
}

variable "agent_container_port" {
  description = "Container listening port exposed by all agent services."
  type        = number
  default     = 8000
}

variable "agent_min_replicas" {
  description = "Minimum replicas for each Container App."
  type        = number
  default     = 0
}

variable "agent_max_replicas" {
  description = "Maximum replicas for each Container App."
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

variable "acr_name_suffix" {
  description = "Optional suffix appended to the ACR name to avoid global collisions across tenants."
  type        = string
  default     = null
}

variable "tags" {
  description = "Shared tags applied to all taggable resources."
  type        = map(string)
}
