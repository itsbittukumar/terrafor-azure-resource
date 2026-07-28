resource "azurerm_service_plan" "this" {
  for_each            = var.app_services
  name                = "${each.key}-plan"
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  os_type             = "Linux"
  sku_name            = each.value.sku_name
}

resource "azurerm_linux_web_app" "this" {
  for_each            = var.app_services
  name                = each.key
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  service_plan_id     = azurerm_service_plan.this[each.key].id

  site_config {}
}
