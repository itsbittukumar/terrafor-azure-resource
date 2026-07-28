variable "network_interfaces" {
  type = map(object({
    resource_group_name = string
    location             = string
    subnet_id             = string
    public_ip_id          = optional(string)
    nsg_id                 = optional(string)
  }))
}
