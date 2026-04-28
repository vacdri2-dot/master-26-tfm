subscription_id = "61881d8c-3db5-4a3f-b9f4-f80e6973affe"

location            = "swedencentral"
environment         = "dev"
project_name        = "tfm-ucm-g2"
resource_group_name = "rg-tfm-ucm-g2-dev"

vnet_cidr = "10.20.0.0/16"

subnet_cidrs = {
  container_apps    = "10.20.0.0/23"
  private_endpoints = "10.20.2.0/24"
  data              = "10.20.3.0/24"
  langfuse          = "10.20.4.0/24"
}

openai_subdomain_suffix = "carlos"
acr_name_suffix         = "carlos"
