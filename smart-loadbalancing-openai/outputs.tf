output "api_endpoint" {
  value = azurerm_api_management.apim.gateway_url
}

output "api_suffix" {
  value = var.openai_api_path
}

output "subscription_key" {
  value = azurerm_api_management_subscription.apim_subscription.primary_key
  sensitive = true
}