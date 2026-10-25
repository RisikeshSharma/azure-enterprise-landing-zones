output "cis_policy_assignment_id" {
  value = length(azurerm_management_group_policy_assignment.cis_assignment) > 0 ? azurerm_management_group_policy_assignment.cis_assignment[0].id : null
}
