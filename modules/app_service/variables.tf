variable "app_services" {
  type = map(object({
    resource_group_name = string
    location             = string
    sku_name              = string
  }))
}
