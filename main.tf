# ==============================================================================
# Root Module: Azure Enterprise Landing Zones (CAF Architecture)
# Author: Rishikesh Sharma
# ==============================================================================

# 1. Management Groups Hierarchy (Platform, Landing Zones, Sandbox)
module "management_groups" {
  count  = var.deploy_management_groups ? 1 : 0
  source = "./modules/management_groups"

  root_management_group_id   = "mg-${var.workload_name}-root"
  root_management_group_name = "${var.organization_name} Root"
}

# 2. Central Connectivity Hub & Security Platform
module "hub_connectivity" {
  source = "./modules/hub_connectivity"

  workload_name        = var.workload_name
  environment          = var.environment
  location             = var.location
  hub_address_space    = var.hub_vnet_cidr
  hub_subnets          = var.hub_subnets
  firewall_sku_tier    = var.firewall_sku_tier
  deploy_azure_bastion = var.deploy_azure_bastion
  tags                 = var.tags
}

# 3. Dynamic Multi-Tenant Spoke Landing Zones using for_each
module "spoke_landing_zones" {
  for_each = var.spoke_landing_zones
  source   = "./modules/spoke_workload"

  spoke_name               = each.key
  environment              = var.environment
  location                 = var.location
  address_space            = each.value.address_space
  subnets                  = each.value.subnets
  security_rules           = var.default_spoke_security_rules
  hub_vnet_id              = module.hub_connectivity.hub_vnet_id
  hub_vnet_name            = module.hub_connectivity.hub_vnet_name
  hub_resource_group_name  = module.hub_connectivity.hub_resource_group_name
  firewall_private_ip      = module.hub_connectivity.azure_firewall_private_ip
  private_dns_zone_ids     = module.hub_connectivity.private_dns_zone_ids
  tags                     = merge(var.tags, { Spoke = each.key })
}

# 4. Governance & CIS Security Policy Initiative
module "governance_policy" {
  count  = var.enable_cis_policy_initiative ? 1 : 0
  source = "./modules/governance_policy"

  enforce_cis_benchmark      = var.enable_cis_policy_initiative
  target_management_group_id = var.deploy_management_groups ? module.management_groups[0].landing_zones_management_group_id : ""
  location                   = var.location
}
