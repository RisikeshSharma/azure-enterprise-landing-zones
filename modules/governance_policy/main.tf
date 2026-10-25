# ==============================================================================
# Governance & Policy Initiatives Module
# Enforces CIS Benchmarks and Enterprise Guardrails
# ==============================================================================

# 1. Built-in CIS Microsoft Azure Benchmark Initiative Data Source
data "azurerm_policy_set_definition" "cis_benchmark" {
  display_name = "CIS Microsoft Azure Foundations Benchmark v2.0.0"
}

# 2. Policy Assignment on Target Management Group or Subscription (Conditional)
resource "azurerm_management_group_policy_assignment" "cis_assignment" {
  count = var.enforce_cis_benchmark && var.target_management_group_id != "" ? 1 : 0

  name                 = "assign-cis-v2"
  management_group_id  = var.target_management_group_id
  policy_definition_id = data.azurerm_policy_set_definition.cis_benchmark.id
  display_name         = "CIS Microsoft Azure Benchmark v2.0.0 Initiative"
  description          = "Enforces 100% compliance against CIS security baselines."

  identity {
    type = "SystemAssigned"
  }

  location = var.location
}
