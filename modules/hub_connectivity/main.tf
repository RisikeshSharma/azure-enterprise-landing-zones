# ==============================================================================
# Hub Connectivity Module - Central Network Hub & Security Platform
# ==============================================================================

# 1. Resource Group for Connectivity Hub
resource "azurerm_resource_group" "hub_rg" {
  name     = "rg-${var.workload_name}-connectivity-${var.environment}"
  location = var.location
  tags     = var.tags
}

# 2. Central Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.workload_name}-${var.location}-${var.environment}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  address_space       = var.hub_address_space
  tags                = var.tags
}

# 3. Hub Subnets with dynamic delegation block
resource "azurerm_subnet" "subnets" {
  for_each = var.hub_subnets

  name                                          = each.key
  resource_group_name                           = azurerm_resource_group.hub_rg.name
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

# 4. Central Log Analytics Workspace for Network Flow & Threat Analytics
resource "azurerm_log_analytics_workspace" "hub_logs" {
  name                = "log-hub-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# 5. Azure Firewall Public IPs
resource "azurerm_public_ip" "afw_pip" {
  name                = "pip-afw-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "afw_mgmt_pip" {
  name                = "pip-afw-mgmt-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# 6. Azure Firewall Premium Policy with TLS Inspection & IDPS
resource "azurerm_firewall_policy" "afw_policy" {
  name                = "afwp-${var.workload_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.hub_rg.name
  location            = azurerm_resource_group.hub_rg.location
  sku                 = var.firewall_sku_tier

  threat_intelligence_mode = "Alert"

  intrusion_detection {
    mode = var.firewall_sku_tier == "Premium" ? "Deny" : "Off"
  }

  dns {
    proxy_enabled = true
  }

  tags = var.tags
}

# 7. Azure Firewall Premium Instance
resource "azurerm_firewall" "afw" {
  name                = "afw-hub-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.afw_policy.id
  zones               = ["1", "2", "3"]
  tags                = var.tags

  ip_configuration {
    name                 = "afw-primary-ipconfig"
    subnet_id            = azurerm_subnet.subnets["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.afw_pip.id
  }

  management_ip_configuration {
    name                 = "afw-mgmt-ipconfig"
    subnet_id            = azurerm_subnet.subnets["AzureFirewallManagementSubnet"].id
    public_ip_address_id = azurerm_public_ip.afw_mgmt_pip.id
  }
}

# 8. Azure Bastion Host for Zero-Trust Jumpbox Access (Conditional Iteration)
resource "azurerm_public_ip" "bastion_pip" {
  count = var.deploy_azure_bastion ? 1 : 0

  name                = "pip-bastion-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "bastion" {
  count = var.deploy_azure_bastion ? 1 : 0

  name                = "bas-${var.workload_name}-${var.environment}"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku                 = "Standard"
  tunneling_enabled   = true
  ip_connect_enabled  = true
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.subnets["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion_pip[0].id
  }
}

# 9. Private DNS Zones with for_each
resource "azurerm_private_dns_zone" "dns_zones" {
  for_each = var.private_dns_zone_names

  name                = each.value
  resource_group_name = azurerm_resource_group.hub_rg.name
  tags                = var.tags
}

# 10. Link Private DNS Zones to Hub VNet
resource "azurerm_private_dns_zone_virtual_network_link" "hub_links" {
  for_each = azurerm_private_dns_zone.dns_zones

  name                  = "link-hub-${each.key}"
  resource_group_name   = azurerm_resource_group.hub_rg.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}
