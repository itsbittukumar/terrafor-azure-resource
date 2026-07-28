resource "azurerm_mssql_server" "this" {
  for_each                     = var.sql_databases
  name                          = each.key
  resource_group_name           = each.value.resource_group_name
  location                      = each.value.location
  version                       = "12.0"
  administrator_login            = each.value.server_admin_login
  administrator_login_password   = each.value.server_admin_password
}

resource "azurerm_mssql_database" "this" {
  for_each  = var.sql_databases
  name      = each.value.database_name
  server_id = azurerm_mssql_server.this[each.key].id
  sku_name  = each.value.sku_name
}
