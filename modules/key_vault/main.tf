resource "azurerm_key_vault" "this" {
  for_each            = var.key_vaults
  name                = each.key
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  sku_name            = each.value.sku_name
  tenant_id           = each.value.tenant_id

  purge_protection_enabled = false
}
