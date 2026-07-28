resource "azurerm_service_plan" "this" {
  for_each            = var.function_apps
  name                = "${each.key}-plan"
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  os_type             = "Linux"
  sku_name            = each.value.sku_name
}

resource "azurerm_storage_account" "this" {
  for_each                 = var.function_apps
  name                      = "${replace(each.key, "-", "")}sa"
  resource_group_name       = each.value.resource_group_name
  location                  = each.value.location
  account_tier               = "Standard"
  account_replication_type   = "LRS"
}

resource "azurerm_linux_function_app" "this" {
  for_each                   = var.function_apps
  name                        = each.key
  resource_group_name         = each.value.resource_group_name
  location                    = each.value.location
  service_plan_id             = azurerm_service_plan.this[each.key].id
  storage_account_name         = azurerm_storage_account.this[each.key].name
  storage_account_access_key   = azurerm_storage_account.this[each.key].primary_access_key

  site_config {}
}
