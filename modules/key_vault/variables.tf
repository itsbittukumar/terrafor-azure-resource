variable "key_vaults" {
  type = map(object({
    resource_group_name = string
    location             = string
    sku_name              = string
    tenant_id             = string
  }))
}
