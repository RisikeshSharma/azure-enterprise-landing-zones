# ==============================================================================
# Spoke Workload Landing Zone Module - Reusable Enterprise Spoke
# ==============================================================================

resource "azurerm_resource_group" "spoke_rg" {
  name     = "rg-${var.spoke_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# 1. Spoke Virtual Network
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "vnet-${var.spoke_name}-${var.environment}"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  address_space       = var.address_space
  tags                = var.tags
}

# 2. Spoke Subnets with for_each and dynamic delegation
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                                          = each.key
  resource_group_name                           = azurerm_resource_group.spoke_rg.name
  virtual_network_name                          = azurerm_virtual_network.spoke_vnet.name
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

# 3. Network Security Group with Dynamic Security Rules
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.spoke_name}-${var.environment}"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = var.security_rules
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

# Associate NSG to each subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  for_each = azurerm_subnet.subnets

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 4. Route Table enforcing 0.0.0.0/0 egress to Azure Firewall
resource "azurerm_route_table" "udr" {
  name                          = "rt-${var.spoke_name}-egress-${var.environment}"
  location                      = azurerm_resource_group.spoke_rg.location
  resource_group_name           = azurerm_resource_group.spoke_rg.name
  disable_bgp_route_propagation = false
  tags                          = var.tags

  route {
    name                   = "DefaultEgressToAzureFirewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

# Associate UDR to each subnet
resource "azurerm_subnet_route_table_association" "udr_assoc" {
  for_each = azurerm_subnet.subnets

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.udr.id
}

# 5. Bi-directional VNet Peering: Spoke <-> Hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.spoke_name}-to-hub"
  resource_group_name          = azurerm_resource_group.spoke_rg.name
  virtual_network_name         = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-${var.spoke_name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

# 6. Link Private DNS Zones to Spoke VNet
resource "azurerm_private_dns_zone_virtual_network_link" "dns_links" {
  for_each = var.private_dns_zone_ids

  name                  = "link-${var.spoke_name}-${each.key}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = split("/", each.value)[8]
  virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
  registration_enabled  = false
  tags                  = var.tags
}
