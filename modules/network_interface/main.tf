resource "azurerm_network_interface" "this" {
  for_each            = var.network_interfaces
  name                = each.key
  resource_group_name = each.value.resource_group_name
  location            = each.value.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = each.value.public_ip_id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  for_each                  = { for k, v in var.network_interfaces : k => v if v.nsg_id != null }
  network_interface_id      = azurerm_network_interface.this[each.key].id
  network_security_group_id = each.value.nsg_id
}
