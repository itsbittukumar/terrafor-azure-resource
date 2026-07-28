variable "sql_databases" {
  type = map(object({
    resource_group_name = string
    location             = string
    server_admin_login    = string
    server_admin_password = string
    database_name          = string
    sku_name                = string
  }))
  sensitive = true
}
