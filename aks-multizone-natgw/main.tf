module "Common" {
  source = "./Modules/Common"

  resource_group_name = var.project_name
  location            = var.location
}

module "Networking" {
  source = "./Modules/Networking"

  resource_group_name = module.Common.resource_group_name
  location            = var.location
}

module "Cluster" {
  source = "./Modules/Cluster"

  resource_group_name          = module.Common.resource_group_name
  location                     = var.location
  log_analytics_workspace_name = module.Common.log_analytics_workspace_name
  container_registry_name      = module.Common.container_registry_name
  virtual_network_name         = module.Networking.virtual_network_name
  admin_users                  = var.cluster_admin_users
}

module "ClusterOperations" {
  source = "./Modules/ClusterOperations"

  resource_group_name = module.Common.resource_group_name
  location            = var.location
  key_vault_name      = module.Common.key_vault_name
  cluster_name        = module.Cluster.cluster_name
  admin_users         = var.cluster_admin_users
}
