resource "azurerm_log_analytics_workspace" "this" {
  for_each            = var.log_analytics_workspaces
  name                = each.key
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  sku                 = each.value.sku
  retention_in_days   = 30
}
