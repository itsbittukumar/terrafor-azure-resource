output "sql_servers" {
  value = azurerm_mssql_server.this
}

output "sql_databases" {
  value = azurerm_mssql_database.this
}
