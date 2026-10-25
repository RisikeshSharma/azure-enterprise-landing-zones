output "root_management_group_id" {
  description = "ID of the root management group."
  value       = azurerm_management_group.root.id
}

output "platform_management_group_id" {
  description = "ID of the Platform management group."
  value       = azurerm_management_group.level2["platform"].id
}

output "landing_zones_management_group_id" {
  description = "ID of the Landing Zones management group."
  value       = azurerm_management_group.level2["landing-zones"].id
}

output "connectivity_management_group_id" {
  description = "ID of the Connectivity management group."
  value       = azurerm_management_group.platform_children["connectivity"].id
}
