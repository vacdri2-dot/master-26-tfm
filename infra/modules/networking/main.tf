resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

locals {
  private_dns_zone_names = {
    key_vault  = "privatelink.vaultcore.azure.net"
    storage    = "privatelink.blob.core.windows.net"
    ai_search  = "privatelink.search.windows.net"
    openai     = "privatelink.openai.azure.com"
    postgresql = "privatelink.postgres.database.azure.com"
  }
}

resource "azurerm_subnet" "this" {
  for_each = {
    container-apps    = var.subnet_cidrs.container_apps
    private-endpoints = var.subnet_cidrs.private_endpoints
    data              = var.subnet_cidrs.data
    langfuse          = var.subnet_cidrs.langfuse
  }

  name                 = "snet-${each.key}-${var.name_prefix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]

  private_endpoint_network_policies = each.key == "private-endpoints" ? "Disabled" : "NetworkSecurityGroupEnabled"

  dynamic "delegation" {
    for_each = each.key == "container-apps" ? [1] : []

    content {
      name = "container-apps-delegation"

      service_delegation {
        name = "Microsoft.App/environments"

        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
        ]
      }
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = azurerm_subnet.this

  name                = "nsg-${each.key}-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "allow_https_from_container_apps_to_data" {
  name                        = "allow-https-containerapps-data"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.subnet_cidrs.container_apps
  destination_address_prefix  = var.subnet_cidrs.data
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this["container-apps"].name
}

resource "azurerm_network_security_rule" "allow_https_from_container_apps_to_internet" {
  name                        = "allow-https-containerapps-internet"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.subnet_cidrs.container_apps
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this["container-apps"].name
}

resource "azurerm_network_security_rule" "allow_postgres_to_langfuse" {
  name                        = "allow-postgres-langfuse"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = var.subnet_cidrs.container_apps
  destination_address_prefix  = var.subnet_cidrs.langfuse
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this["langfuse"].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = azurerm_subnet.this

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zone_names

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = azurerm_private_dns_zone.this

  name                  = "vnet-link-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags
}
