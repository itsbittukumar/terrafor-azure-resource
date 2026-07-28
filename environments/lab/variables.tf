variable "subscription_id" {
  type = string
}

variable "vm_admin_ssh_public_key" {
  type = string
}

variable "key_vault_tenant_id" {
  type = string
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

variable "resource_groups" {
  type = map(object({
    location = string
    tags     = optional(map(string), {})
  }))
  default = {}
}

variable "virtual_networks" {
  type = map(object({
    resource_group_name = string
    location             = string
    address_space         = list(string)
    subnets = map(object({
      address_prefixes = list(string)
    }))
  }))
  default = {}
}

variable "network_security_groups" {
  type = map(object({
    resource_group_name = string
    location             = string
  }))
  default = {}
}

variable "public_ips" {
  type = map(object({
    resource_group_name = string
    location             = string
    allocation_method     = string
  }))
  default = {}
}

variable "network_interfaces" {
  type = map(object({
    resource_group_name = string
    location             = string
    vnet_key               = string
    subnet_key             = string
    public_ip_key          = optional(string)
    nsg_key                 = optional(string)
  }))
  default = {}
}

variable "linux_vms" {
  type = map(object({
    resource_group_name = string
    location             = string
    size                  = string
    admin_username         = string
    nic_key                = string
    os_disk_storage_type   = string
  }))
  default = {}
}

variable "log_analytics_workspaces" {
  type = map(object({
    resource_group_name = string
    location             = string
    sku                   = string
  }))
  default = {}
}

variable "key_vaults" {
  type = map(object({
    resource_group_name = string
    location             = string
    sku_name              = string
  }))
  default = {}
}

variable "app_services" {
  type = map(object({
    resource_group_name = string
    location             = string
    sku_name              = string
  }))
  default = {}
}

variable "function_apps" {
  type = map(object({
    resource_group_name = string
    location             = string
    sku_name              = string
  }))
  default = {}
}

variable "sql_databases" {
  type = map(object({
    resource_group_name = string
    location             = string
    server_admin_login    = string
    database_name          = string
    sku_name                = string
  }))
  default = {}
}
