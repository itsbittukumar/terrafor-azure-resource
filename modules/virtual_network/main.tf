resource "azurerm_virtual_network" "this" {
  for_each            = var.virtual_networks
  name                = each.key
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  address_space       = each.value.address_space
}

resource "azurerm_subnet" "this" {
  for_each = {
    for pair in flatten([
      for vnet_key, vnet in var.virtual_networks : [
        for subnet_key, subnet in vnet.subnets : {
          key                 = "${vnet_key}/${subnet_key}"
          vnet_key            = vnet_key
          subnet_name         = subnet_key
          address_prefixes    = subnet.address_prefixes
          resource_group_name = vnet.resource_group_name
        }
      ]
    ]) : pair.key => pair
  }

  name                 = each.value.subnet_name
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = azurerm_virtual_network.this[each.value.vnet_key].name
  address_prefixes     = each.value.address_prefixes
}
