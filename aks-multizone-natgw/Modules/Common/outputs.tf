output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "log_analytics_workspace_name" {
  value = azurerm_log_analytics_workspace.log_analytics_workspace.name
}

output "container_registry_name" {
  value = azurerm_container_registry.container_registry.name
}

output "key_vault_name" {
  value = azurerm_key_vault.key_vault.name
}
