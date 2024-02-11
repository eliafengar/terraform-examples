output "api_endpoint" {
  value = azurerm_api_management.apim.gateway_url
}

output "api_suffix" {
  value = var.openai_api_path
}
