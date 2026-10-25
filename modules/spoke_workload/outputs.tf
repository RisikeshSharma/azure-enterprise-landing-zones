output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke_vnet.id
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.spoke_vnet.name
}

output "subnet_ids" {
  value = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "route_table_id" {
  value = azurerm_route_table.udr.id
}

output "nsg_id" {
  value = azurerm_network_security_group.nsg.id
}
