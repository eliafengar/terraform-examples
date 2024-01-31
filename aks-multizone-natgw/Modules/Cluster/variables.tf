variable "resource_group_name" {}
variable "location" {}
variable "log_analytics_workspace_name" {}
variable "container_registry_name" {}
variable "virtual_network_name" {}
variable "admin_users" {}

variable "default_nodepool_vm_size" {
  default = "Standard_D2s_v5"
}

variable "service_cidr" {
  default = "20.0.0.0/16"
}

variable "dns_service_ip" {
  default = "20.0.0.10"
}

variable "nodepools" {
  description = "Nodepools for the Kubernetes cluster"
  type = map(object({
    name                = string
    zones               = list(number)
    vm_size             = string
    min_count           = number
    max_count           = number
    enable_auto_scaling = bool
    subnet_key          = string
  }))
  default = {
    zone_1_workers = {
      name                = "zone1workers"
      zones               = [1]
      vm_size             = "Standard_D2s_v5"
      min_count           = 1
      max_count           = 10
      enable_auto_scaling = true
      subnet_key          = "zone1Subnet"
    },
    zone_2_workers = {
      name                = "zone2workers"
      zones               = [2]
      vm_size             = "Standard_D2s_v5"
      min_count           = 1
      max_count           = 10
      enable_auto_scaling = true
      subnet_key          = "zone2Subnet"
    },
    zone_3_workers = {
      name                = "zone3workers"
      zones               = [3]
      vm_size             = "Standard_D2s_v5"
      min_count           = 1
      max_count           = 10
      enable_auto_scaling = true
      subnet_key          = "zone3Subnet"
    }
  }
}
