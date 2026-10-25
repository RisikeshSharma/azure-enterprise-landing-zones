# ==============================================================================
# Azure Enterprise Landing Zones - Root Module
# Production-grade implementation of Microsoft Cloud Adoption Framework (CAF)
# ==============================================================================

# 1. Primary Platform Resource Group
resource "azurerm_resource_group" "connectivity" {
  name     = "rg-${var.workload_name}-connectivity-${var.environment}"
  location = var.location
  tags     = var.tags
}

# 2. Central Connectivity Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.workload_name}-${var.location}-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = var.hub_vnet_cidr
  tags                = var.tags
}

# 3. Hub Subnets created using for_each with dynamic delegation block
resource "azurerm_subnet" "hub_subnets" {
  for_each = var.hub_subnets

  name                                          = each.key
  resource_group_name                           = azurerm_resource_group.connectivity.name
  virtual_network_name                          = azurerm_virtual_network.hub.name
  address_prefixes                              = each.value.address_prefixes
  service_endpoints                             = lookup(each.value, "service_endpoints", [])
  private_endpoint_network_policies_enabled     = lookup(each.value, "private_endpoint_network_policies_enabled", true)

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

# 4. Azure Firewall Public IPs (Multi-IP scalable setup)
resource "azurerm_public_ip" "firewall_pip" {
  name                = "pip-afw-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "firewall_mgmt_pip" {
  name                = "pip-afw-mgmt-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# 5. Azure Firewall Policy with TLS Inspection and IDPS
resource "azurerm_firewall_policy" "hub_policy" {
  name                = "afwp-${var.workload_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.connectivity.name
  location            = azurerm_resource_group.connectivity.location
  sku                 = var.firewall_sku_tier

  threat_intelligence_mode = "Alert"

  intrusion_detection {
    mode = var.firewall_sku_tier == "Premium" ? "Deny" : "Off"
  }

  tags = var.tags
}

# 6. Azure Firewall Premium with Dynamic IP Configuration block
resource "azurerm_firewall" "hub_fw" {
  name                = "afw-hub-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.hub_policy.id
  zones               = ["1", "2", "3"]
  tags                = var.tags

  dynamic "ip_configuration" {
    for_each = [
      {
        name                 = "fw-primary-ipconfig"
        subnet_id            = azurerm_subnet.hub_subnets["AzureFirewallSubnet"].id
        public_ip_address_id = azurerm_public_ip.firewall_pip.id
      }
    ]
    content {
      name                 = ip_configuration.value.name
      subnet_id            = ip_configuration.value.subnet_id
      public_ip_address_id = ip_configuration.value.public_ip_address_id
    }
  }

  management_ip_configuration {
    name                 = "fw-mgmt-ipconfig"
    subnet_id            = azurerm_subnet.hub_subnets["AzureFirewallManagementSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall_mgmt_pip.id
  }
}

# 7. Enterprise Spoke VNets with for_each
resource "azurerm_resource_group" "spokes" {
  for_each = var.spoke_vnets

  name     = "rg-${each.key}-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spokes" {
  for_each = var.spoke_vnets

  name                = "vnet-${each.key}"
  location            = azurerm_resource_group.spokes[each.key].location
  resource_group_name = azurerm_resource_group.spokes[each.key].name
  address_space       = each.value.cidr_block
  tags                = var.tags
}

# 8. Spoke Subnets flattened iteration with for_each
locals {
  spoke_subnets_flat = merge([
    for spoke_key, spoke_val in var.spoke_vnets : {
      for subnet_key, subnet_val in spoke_val.subnets :
      "${spoke_key}.${subnet_key}" => {
        spoke_key         = spoke_key
        subnet_name       = subnet_key
        cidr_block        = subnet_val.cidr_block
        service_endpoints = lookup(subnet_val, "service_endpoints", [])
      }
    }
  ]...)
}

resource "azurerm_subnet" "spoke_subnets" {
  for_each = local.spoke_subnets_flat

  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.spokes[each.value.spoke_key].name
  virtual_network_name = azurerm_virtual_network.spokes[each.value.spoke_key].name
  address_prefixes     = each.value.cidr_block
  service_endpoints    = each.value.service_endpoints
}

# 9. Bi-directional Hub-to-Spoke VNet Peerings (Conditional Iteration)
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = {
    for k, v in var.spoke_vnets : k => v if v.enable_hub_peering
  }

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.connectivity.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spokes[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = each.value.allow_forwarded_traf
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = {
    for k, v in var.spoke_vnets : k => v if v.enable_hub_peering
  }

  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.spokes[each.key].name
  virtual_network_name         = azurerm_virtual_network.spokes[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

# 10. Default Network Security Group with Dynamic Security Rules block
resource "azurerm_network_security_group" "spoke_nsg" {
  for_each = var.spoke_vnets

  name                = "nsg-${each.key}-${var.environment}"
  location            = azurerm_resource_group.spokes[each.key].location
  resource_group_name = azurerm_resource_group.spokes[each.key].name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = var.network_security_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
      description                = lookup(security_rule.value, "description", null)
    }
  }
}

# 11. User-Defined Route (UDR) forcing all outbound egress through Azure Firewall Premium
resource "azurerm_route_table" "spoke_udr" {
  for_each = var.spoke_vnets

  name                = "rt-${each.key}-egress-${var.environment}"
  location            = azurerm_resource_group.spokes[each.key].location
  resource_group_name = azurerm_resource_group.spokes[each.key].name
  tags                = var.tags

  route {
    name                   = "DefaultRouteToAzureFirewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
  }
}
