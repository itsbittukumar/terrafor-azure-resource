variable "virtual_networks" {
  type = map(object({
    resource_group_name = string
    location             = string
    address_space         = list(string)
    subnets = map(object({
      address_prefixes = list(string)
    }))
  }))
}
