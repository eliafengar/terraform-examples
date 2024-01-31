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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25.2"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {
}

data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

# data "azuread_service_principal" "aks" {
#   display_name = "Azure Kubernetes Service AAD Server"
# }

# Provider to Connect with permissioned user and not admin
# provider "kubernetes" {
#   host = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host

#   # client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
#   # client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
#   cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)

#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "kubelogin"
#     args = [
#       "get-token",
#       "--login",
#       "azurecli",
#       "--server-id",
#       data.azuread_service_principal.aks.application_id
#     ]
#   }
# }

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_admin_config.0.cluster_ca_certificate)
}

resource "azurerm_user_assigned_identity" "key_vault_secrets_provider_identity" {
  location            = var.location
  name                = "${var.cluster_name}keyvaultidentity"
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "csi_role_assignment" {
  principal_id                     = azurerm_user_assigned_identity.key_vault_secrets_provider_identity.client_id
  role_definition_name             = "Key Vault Administrator"
  scope                            = data.azurerm_key_vault.key_vault.id
  skip_service_principal_aad_check = true
}

locals {
  service_account_name      = "workload-identity-sa"
  service_account_namespace = "default"
}

resource "azurerm_federated_identity_credential" "csi_federated_credentials" {
  name                = "${var.cluster_name}federatedidentity"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.key_vault_secrets_provider_identity.id
  subject             = "system:serviceaccount:${local.service_account_namespace}:${local.service_account_name}"
}

resource "kubernetes_service_account_v1" "csi_service_account" {
  metadata {
    name      = local.service_account_name
    namespace = local.service_account_namespace
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.key_vault_secrets_provider_identity.client_id
    }
  }
}

resource "kubernetes_manifest" "secret_class_provider" {
  manifest = {
    "apiVersion" = "secrets-store.csi.x-k8s.io/v1"
    "kind"       = "SecretProviderClass"
    "metadata" = {
      "name"      = "azure-kvname-wi"
      "namespace" = "default"
    }
    "spec" = {
      "parameters" = {
        "clientID"       = "${azurerm_user_assigned_identity.key_vault_secrets_provider_identity.client_id}"
        "keyvaultName"   = "${var.key_vault_name}"
        "objects"        = <<-EOT
      array:
        - |
          objectName: secret1             # Set to the name of your secret
          objectType: secret              # object types: secret, key, or cert
          objectVersion: ""               # [OPTIONAL] object versions, default to latest if empty
        - |
          objectName: key1                # Set to the name of your key
          objectType: key
          objectVersion: ""
      EOT
        "tenantId"       = "${data.azurerm_client_config.current.tenant_id}"
        "usePodIdentity" = "false"
      }
      "provider" = "azure"
    }
  }
}

locals {
  role_suffix         = "user-full-access"
  role_binding_suffix = "user-access"
}

resource "kubernetes_role_v1" "user_role" {
  # count    = var.generate_k8s_roles ? 1 : 0
  # for_each = var.admin_users
  for_each = { for k in compact([for k, v in var.admin_users : var.generate_k8s_roles ? k : ""]) : k => var.admin_users[k] }

  metadata {
    name      = "${each.key}-${local.role_suffix}"
    namespace = "default"
  }

  rule {
    api_groups = ["", "extensions", "apps"]
    resources  = ["*"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding_v1" "user_role_binding" {
  # count    = var.generate_k8s_roles ? 1 : 0
  # for_each = var.admin_users
  for_each = { for k in compact([for k, v in var.admin_users : var.generate_k8s_roles ? k : ""]) : k => var.admin_users[k] }

  metadata {
    name      = "${each.key}-${local.role_binding_suffix}"
    namespace = "default"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "${each.key}-${local.role_suffix}"
  }
  subject {
    kind      = "User"
    name      = each.value.objectId
    api_group = "rbac.authorization.k8s.io"
  }
}
