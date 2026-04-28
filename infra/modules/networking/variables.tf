variable "location" {
  description = "Azure region where networking resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name where networking resources will be created."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming networking resources."
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network."
  type        = string
}

variable "subnet_cidrs" {
  description = "CIDR blocks for networking subnets."
  type = object({
    container_apps    = string
    private_endpoints = string
    data              = string
    langfuse          = string
  })
}

variable "tags" {
  description = "Shared tags applied to all taggable resources."
  type        = map(string)
}
