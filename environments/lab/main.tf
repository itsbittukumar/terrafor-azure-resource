module "resource_groups" {
  source          = "../../modules/resource_group"
  resource_groups = var.resource_groups
}

module "virtual_networks" {
  source           = "../../modules/virtual_network"
  virtual_networks = var.virtual_networks
  depends_on       = [module.resource_groups]
}

module "network_security_groups" {
  source                  = "../../modules/network_security_group"
  network_security_groups = var.network_security_groups
  depends_on               = [module.resource_groups]
}

module "public_ips" {
  source     = "../../modules/public_ip"
  public_ips = var.public_ips
  depends_on  = [module.resource_groups]
}

module "network_interfaces" {
  source = "../../modules/network_interface"
  network_interfaces = {
    for k, v in var.network_interfaces : k => {
      resource_group_name = v.resource_group_name
      location             = v.location
      subnet_id             = module.virtual_networks.subnets["${v.vnet_key}/${v.subnet_key}"].id
      public_ip_id          = v.public_ip_key != null ? module.public_ips.public_ips[v.public_ip_key].id : null
      nsg_id                 = v.nsg_key != null ? module.network_security_groups.nsgs[v.nsg_key].id : null
    }
  }
  depends_on = [module.virtual_networks, module.public_ips, module.network_security_groups]
}

module "linux_vms" {
  source = "../../modules/linux_virtual_machine"
  linux_vms = {
    for k, v in var.linux_vms : k => {
      resource_group_name  = v.resource_group_name
      location              = v.location
      size                   = v.size
      admin_username          = v.admin_username
      ssh_public_key          = var.vm_admin_ssh_public_key
      nic_id                   = module.network_interfaces.nics[v.nic_key].id
      os_disk_storage_type    = v.os_disk_storage_type
    }
  }
  depends_on = [module.network_interfaces]
}

module "log_analytics_workspaces" {
  source                    = "../../modules/log_analytics_workspace"
  log_analytics_workspaces  = var.log_analytics_workspaces
  depends_on                 = [module.resource_groups]
}

module "key_vaults" {
  source = "../../modules/key_vault"
  key_vaults = {
    for k, v in var.key_vaults : k => merge(v, { tenant_id = var.key_vault_tenant_id })
  }
  depends_on = [module.resource_groups]
}

module "app_services" {
  source       = "../../modules/app_service"
  app_services = var.app_services
  depends_on    = [module.resource_groups]
}

module "function_apps" {
  source         = "../../modules/function_app"
  function_apps  = var.function_apps
  depends_on      = [module.resource_groups]
}

module "sql_databases" {
  source = "../../modules/sql_database"
  sql_databases = {
    for k, v in var.sql_databases : k => merge(v, { server_admin_password = var.sql_admin_password })
  }
  depends_on = [module.resource_groups]
}
