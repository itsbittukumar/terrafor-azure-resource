resource "azurerm_public_ip" "this" {
  for_each            = var.public_ips
  name                = each.key
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  allocation_method   = each.value.allocation_method
  sku                 = "Standard"
}
