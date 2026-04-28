output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "subnet_ids" {
  description = "IDs of the networking subnets."
  value = {
    for subnet_name, subnet in azurerm_subnet.this :
    subnet_name => subnet.id
  }
}

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs by service key."
  value = {
    for service, zone in azurerm_private_dns_zone.this :
    service => zone.id
  }
}

output "private_dns_zone_names" {
  description = "Private DNS zone names by service key."
  value = {
    for service, zone in azurerm_private_dns_zone.this :
    service => zone.name
  }
}

output "private_endpoint_defaults" {
  description = "Base private endpoint configuration consumed by other modules."
  value = {
    subnet_id = azurerm_subnet.this["private-endpoints"].id
    services = {
      key_vault = {
        subresource_names = ["vault"]
        private_dns_zone_ids = [
          azurerm_private_dns_zone.this["key_vault"].id,
        ]
      }
      storage_blob = {
        subresource_names = ["blob"]
        private_dns_zone_ids = [
          azurerm_private_dns_zone.this["storage"].id,
        ]
      }
      ai_search = {
        subresource_names = ["searchService"]
        private_dns_zone_ids = [
          azurerm_private_dns_zone.this["ai_search"].id,
        ]
      }
      openai = {
        subresource_names = ["account"]
        private_dns_zone_ids = [
          azurerm_private_dns_zone.this["openai"].id,
        ]
      }
      postgresql = {
        subresource_names = ["postgresqlServer"]
        private_dns_zone_ids = [
          azurerm_private_dns_zone.this["postgresql"].id,
        ]
      }
    }
  }
}
