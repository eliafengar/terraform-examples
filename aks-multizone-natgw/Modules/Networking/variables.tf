variable "resource_group_name" {}

variable "location" {}

variable "network_name_suffix" {
  default = "vnet"
}

variable "address_space" {
  default = ["10.0.0.0/16"]
}

variable "default_subnet_address_prefix" {
  default = ["10.0.0.0/24"]
}

variable "subnetwithNatGateways" {
  description = "Subnets for AKS NodePools"
  type = map(object({
    subnet_name                = string
    address_prefix             = list(string)
    nat_gateway_name           = string
    nat_gateway_public_ip_name = string
  }))
  default = {
    zone1SubnetWithNsgAndNatGW = {
      subnet_name                = "zone1Subnet"
      address_prefix             = ["10.0.1.0/24"]
      nat_gateway_name           = "zone1NatGateway"
      nat_gateway_public_ip_name = "zone1NatGatewayPIP"
    },
    zone2SubnetWithNsgAndNatGW = {
      subnet_name                = "zone2Subnet"
      address_prefix             = ["10.0.2.0/24"]
      nat_gateway_name           = "zone2NatGateway"
      nat_gateway_public_ip_name = "zone2NatGatewayPIP"
    },
    zone3SubnetWithNsgAndNatGW = {
      subnet_name                = "zone3Subnet"
      address_prefix             = ["10.0.3.0/24"]
      nat_gateway_name           = "zone3NatGateway"
      nat_gateway_public_ip_name = "zone3NatGatewayPIP"
    }
  }
}
