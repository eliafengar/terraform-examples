terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.89.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.1"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_id" "number" {
  keepers = {
    rg_id = azurerm_resource_group.rg.id
  }

  byte_length = 8
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_cognitive_account" "cognitive_account" {
  for_each = var.cognitive_accounts

  name                = "${var.cognitive_account_name}-${each.value.location}-${random_id.number.hex}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
}

resource "azurerm_cognitive_deployment" "cognitive_account_deploy" {
  for_each = var.cognitive_accounts

  name                 = var.openai_deployment_name
  cognitive_account_id = azurerm_cognitive_account.cognitive_account[each.key].id
  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }

  scale {
    type = "Standard"
  }
}

resource "azurerm_api_management" "apim" {
  name                = var.api_management.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = var.api_management.company
  publisher_email     = var.api_management.publisher

  sku_name = var.api_management.sku

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "role_assignment_apim" {
  for_each = var.cognitive_accounts

  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
  scope                = azurerm_cognitive_account.cognitive_account[each.key].id
}

resource "azurerm_api_management_api" "apim_openai_api" {
  name                  = var.openai_api_name
  resource_group_name   = azurerm_resource_group.rg.name
  api_management_name   = azurerm_api_management.apim.name
  revision              = "1"
  display_name          = var.openai_api_display_name
  path                  = var.openai_api_path
  protocols             = var.openai_api_protocols
  subscription_required = true
  subscription_key_parameter_names {
    header = "api-key"
    query  = "subscription-key"
  }

  import {
    content_format = "openapi"
    content_value  = file("assets/openai-openapi.json")
  }
}

locals {
  backend_list = [
    for k, v in var.cognitive_accounts : {
      url          = azurerm_cognitive_account.cognitive_account[k].endpoint
      priority     = v.priority
      isThrottling = v.isThrottling
      retryAfter   = "01/01/0001 12:00:00"
    }
  ]
  backend_list_json = replace(jsonencode(local.backend_list), "\"", "'")
}

resource "local_file" "policy_xml" {
  filename = "${path.module}/assets/apim-policy.xml"
  content = templatefile("${path.module}/assets/apim-policy.tftpl", {
    backend_list_str = local.backend_list_json
  })
}

resource "azurerm_api_management_policy" "apim_policy" {
  api_management_id = azurerm_api_management.apim.id
  xml_content       = local_file.policy_xml.content
}

resource "azurerm_api_management_subscription" "apim_subscription" {
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_id              = azurerm_api_management_api.apim_openai_api.id
  display_name        = var.openai_api_subscription_display_name
  state               = "active"
}
