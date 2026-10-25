output "hub_vnet_id" {
  description = "The Resource ID of the central Hub Virtual Network."
  value       = azurerm_virtual_network.hub.id
}

output "hub_subnets" {
  description = "Map of all provisioned Hub subnets."
  value       = { for k, v in azurerm_subnet.hub_subnets : k => v.id }
}

output "azure_firewall_private_ip" {
  description = "Private IP address of Azure Firewall Premium for UDR routing."
  value       = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
}

output "azure_firewall_public_ip" {
  description = "Public IP address of Azure Firewall."
  value       = azurerm_public_ip.firewall_pip.ip_address
}

output "spoke_vnets" {
  description = "Map of provisioned Spoke VNets with IDs and address spaces."
  value = {
    for k, v in azurerm_virtual_network.spokes : k => {
      id            = v.id
      address_space = v.address_space
    }
  }
}
