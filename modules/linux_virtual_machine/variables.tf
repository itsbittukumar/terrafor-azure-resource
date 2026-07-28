variable "linux_vms" {
  type = map(object({
    resource_group_name = string
    location             = string
    size                  = string
    admin_username         = string
    ssh_public_key         = string
    nic_id                  = string
    os_disk_storage_type   = string
  }))
}
