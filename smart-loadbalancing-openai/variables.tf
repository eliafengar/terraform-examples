variable "resource_group_name" {
  default = "smart-lb-oai"
}

variable "location" {
  default = "EastUS"
}

variable "cognitive_account_name" {
  default = "oai"
}

variable "cognitive_accounts" {
  type = map(object({
    location     = string
    priority     = string
    isThrottling = bool
  }))
  default = {
    endpoint1 = {
      location     = "EastUS"
      priority     = 1
      isThrottling = false
    },
    endpoint2 = {
      location     = "CanadaEast"
      priority     = 1
      isThrottling = false
    }
    endpoint3 = {
      location     = "SwedenCentral"
      priority     = 2
      isThrottling = false
    }
  }
}

variable "openai_deployment_name" {
  default = "gpt-35-turbo-16k"
}

variable "openai_model_name" {
  default = "gpt-35-turbo-16k"
}

variable "openai_model_version" {
  default = "0613"
}

variable "api_management" {
  type = object({
    name      = string
    company   = string
    publisher = string
    sku       = string
  })
  default = {
    name      = "smartlb-apim"
    company   = "Microsoft"
    publisher = "eli.afengar@microsoft.com"
    sku       = "Premium_1"
  }
}

variable "openai_api_name" {
  default = "openai-api"
}

variable "openai_api_display_name" {
  default = "OpenAI API"
}

variable "openai_api_path" {
  default = "openai-load-balancing/openai"
}

variable "openai_api_protocols" {
  default = ["http","https"]
}

variable "openai_api_subscription_display_name" {
  default = "Azure OpenAI Service API"
}
