variable "public_ips" {
  type = map(object({
    resource_group_name = string
    location             = string
    allocation_method     = string
  }))
}
