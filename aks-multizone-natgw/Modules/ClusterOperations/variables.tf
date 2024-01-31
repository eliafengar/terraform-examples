variable "resource_group_name" {}
variable "cluster_name" {}
variable "location" {}
variable "key_vault_name" {}
variable "admin_users" {}

variable "generate_k8s_roles" {
  default = false
}
