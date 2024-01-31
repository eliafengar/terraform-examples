output "location" {
  description = "The Deployment Location"
  value       = var.location
}

output "resource_group_name" {
  description = "Resource Group Name"
  value       = module.Common.resource_group_name
}
