# ==============================================================================
# Management Groups Module - Microsoft CAF Hierarchy
# ==============================================================================

# Level 1: Root Management Group
resource "azurerm_management_group" "root" {
  display_name               = var.root_management_group_name
  name                       = var.root_management_group_id
  parent_management_group_id = var.tenant_root_group_id != "" ? var.tenant_root_group_id : null
}

# Level 2: Core CAF Management Groups (Platform, Landing Zones, Sandbox, Decommissioned)
resource "azurerm_management_group" "level2" {
  for_each = var.core_management_groups

  display_name               = each.value.display_name
  name                       = each.key
  parent_management_group_id = azurerm_management_group.root.id
}

# Level 3: Platform Child Groups (Connectivity, Identity, Management)
resource "azurerm_management_group" "platform_children" {
  for_each = var.platform_child_groups

  display_name               = each.value.display_name
  name                       = each.key
  parent_management_group_id = azurerm_management_group.level2["platform"].id
}

# Level 3: Landing Zones Child Groups (Corp, Online)
resource "azurerm_management_group" "landing_zone_children" {
  for_each = var.landing_zone_child_groups

  display_name               = each.value.display_name
  name                       = each.key
  parent_management_group_id = azurerm_management_group.level2["landing-zones"].id
}
