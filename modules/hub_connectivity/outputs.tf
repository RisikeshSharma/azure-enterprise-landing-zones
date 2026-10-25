output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "hub_resource_group_name" {
  value = azurerm_resource_group.hub_rg.name
}

output "azure_firewall_private_ip" {
  value = azurerm_firewall.afw.ip_configuration[0].private_ip_address
}

output "azure_firewall_public_ip" {
  value = azurerm_public_ip.afw_pip.ip_address
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.hub_logs.id
}

output "private_dns_zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.dns_zones : k => v.id }
}
