variable "project_name" {
  default = ""
}

variable "location" {
  default = ""
}

variable "cluster_admin_users" {
  description = "Admin Users"
  type = map(object({
    objectId = string
  }))
  default = {
    user1 = {
      objectId = null
    }
  }
}
