resource "azurerm_network_security_group" "this" {
  for_each            = var.network_security_groups
  name                = each.key
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
}
