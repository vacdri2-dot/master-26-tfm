variable "location" {
  description = "Azure region where observability resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where observability resources will be created."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming observability resources."
  type        = string
}

variable "retention_days" {
  description = "Number of days to retain logs in Log Analytics Workspace and Application Insights."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "retention_days must be between 30 and 730."
  }
}

variable "daily_cap_gb" {
  description = "Daily ingestion cap in GB for Application Insights. Prevents unexpected billing spikes."
  type        = number
  default     = 1

  validation {
    condition     = var.daily_cap_gb >= 0.1 && var.daily_cap_gb <= 100
    error_message = "daily_cap_gb must be between 0.1 and 100."
  }
}

variable "sampling_percentage" {
  description = "Fixed-rate sampling percentage for Application Insights (1-100)."
  type        = number
  default     = 100

  validation {
    condition     = var.sampling_percentage >= 1 && var.sampling_percentage <= 100
    error_message = "sampling_percentage must be between 1 and 100."
  }
}

variable "tags" {
  description = "Shared tags applied to all taggable resources."
  type        = map(string)
}
