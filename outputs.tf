output "hub_vnet_id" {
  description = "Resource ID of the central Hub Virtual Network."
  value       = module.hub_connectivity.hub_vnet_id
}

output "hub_vnet_name" {
  description = "Name of the central Hub Virtual Network."
  value       = module.hub_connectivity.hub_vnet_name
}

output "azure_firewall_private_ip" {
  description = "Private IP address of Azure Firewall Premium for UDR routing."
  value       = module.hub_connectivity.azure_firewall_private_ip
}

output "azure_firewall_public_ip" {
  description = "Public IP address of Azure Firewall."
  value       = module.hub_connectivity.azure_firewall_public_ip
}

output "log_analytics_workspace_id" {
  description = "Resource ID of central Log Analytics workspace."
  value       = module.hub_connectivity.log_analytics_workspace_id
}

output "spoke_landing_zones" {
  description = "Summary map of all deployed spoke landing zones."
  value = {
    for k, v in module.spoke_landing_zones : k => {
      vnet_id        = v.spoke_vnet_id
      vnet_name      = v.spoke_vnet_name
      subnets        = v.subnet_ids
      route_table_id = v.route_table_id
      nsg_id         = v.nsg_id
    }
  }
}
