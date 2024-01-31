terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.89.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.30.0"
    }
    shell = {
      source  = "scottwinkler/shell"
      version = "1.7.10"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {
}

data "azuread_client_config" "current" {
}

locals {
  cluster_name = "${var.resource_group_name}aks"
}

data "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}

data "azurerm_virtual_network" "network" {
  name                = var.virtual_network_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "network_subnets" {
  for_each             = toset(data.azurerm_virtual_network.network.subnets)
  name                 = each.value
  virtual_network_name = data.azurerm_virtual_network.network.name
  resource_group_name  = data.azurerm_virtual_network.network.resource_group_name
}

resource "azurerm_log_analytics_solution" "log_analytics_solution" {
  solution_name         = "Containers"
  workspace_resource_id = data.azurerm_log_analytics_workspace.log_analytics_workspace.id
  workspace_name        = data.azurerm_log_analytics_workspace.log_analytics_workspace.name
  location              = var.location
  resource_group_name   = var.resource_group_name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Containers"
  }
}

# resource "azuread_group" "k8s_admin_group" {
#   display_name     = "${local.cluster_name}admins"
#   owners           = [data.azuread_client_config.current.object_id]
#   security_enabled = true
# }

### The Following is a Workaround to Azure AD Group Create as there is an Issue creating with the standard resource ###
# provider "shell" {}
locals {
  azuread_admin_group_name = "${local.cluster_name}admins"
  azuread_admin_group_id   = shell_script.azuread_admin_group.output.id
}
resource "shell_script" "azuread_admin_group" {
  lifecycle_commands {
    create = "az ad group create --display-name ${local.azuread_admin_group_name} --mail-nickname ${local.azuread_admin_group_name}"
    read   = "az ad group show --group ${local.azuread_admin_group_name}"
    update = "az ad group delete --group ${local.azuread_admin_group_name} && az ad group create --display-name ${local.azuread_admin_group_name} --mail-nickname ${local.azuread_admin_group_name}"
    delete = "az ad group delete --group ${local.azuread_admin_group_name}"
  }
}

resource "azuread_group_member" "k8s_admin_group_members" {
  for_each = var.admin_users

  group_object_id = local.azuread_admin_group_id
  # group_object_id  = azuread_group.k8s_admin_group.id
  member_object_id = each.value.objectId
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                      = local.cluster_name
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = local.cluster_name
  sku_tier                  = "Standard"
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = var.default_nodepool_vm_size
    vnet_subnet_id = data.azurerm_subnet.network_subnets["default"].id
    # enable_auto_scaling = true
    # min_count           = 1
    # max_count           = 3
  }

  azure_active_directory_role_based_access_control {
    managed   = true
    tenant_id = data.azurerm_client_config.current.tenant_id
    # admin_group_object_ids = [azuread_group.k8s_admin_group.object_id]
    admin_group_object_ids = [local.azuread_admin_group_id]
    azure_rbac_enabled     = false
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    # network_mode   = "overlay"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
    # pod_cidr       = "192.168.0.0/16"
    # docker_bridge_cidr = "172.17.0.1/16"
  }


  oms_agent {
    log_analytics_workspace_id      = data.azurerm_log_analytics_workspace.log_analytics_workspace.id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

data "azurerm_container_registry" "container_registry" {
  name                = var.container_registry_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "acr_role_assignment" {
  principal_id                     = azurerm_kubernetes_cluster.k8s.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = data.azurerm_container_registry.container_registry.id
  skip_service_principal_aad_check = true
}

resource "azurerm_kubernetes_cluster_node_pool" "nodepools" {
  for_each = var.nodepools

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s.id
  vm_size               = each.value.vm_size
  zones                 = each.value.zones
  node_count            = each.value.min_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  enable_auto_scaling   = each.value.enable_auto_scaling
  vnet_subnet_id        = data.azurerm_subnet.network_subnets[each.value.subnet_key].id
}
