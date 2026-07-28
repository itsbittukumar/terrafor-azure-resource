variable "network_security_groups" {
  type = map(object({
    resource_group_name = string
    location             = string
  }))
}
