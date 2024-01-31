terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.89.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  network_name = "${var.resource_group_name}${var.network_name_suffix}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = local.network_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
}

resource "azurerm_subnet" "default_subnet" {
  name                 = "default"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.default_subnet_address_prefix
}

resource "azurerm_network_security_group" "default_subnet_nsg" {
  name                = "${azurerm_subnet.default_subnet.name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_security_rule" "default_subnet_nsg_rule" {
  name                        = "${azurerm_subnet.default_subnet.name}-rule"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.default_subnet_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "default_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.default_subnet.id
  network_security_group_id = azurerm_network_security_group.default_subnet_nsg.id
}

resource "azurerm_public_ip" "public_ips" {
  for_each = var.subnetwithNatGateways

  name                = each.value.nat_gateway_public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat_gateways" {
  for_each = var.subnetwithNatGateways

  name                = each.value.nat_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "public_ip_association" {
  for_each = var.subnetwithNatGateways

  nat_gateway_id       = azurerm_nat_gateway.nat_gateways[each.key].id
  public_ip_address_id = azurerm_public_ip.public_ips[each.key].id
}

resource "azurerm_subnet" "subnets" {
  for_each = var.subnetwithNatGateways

  name                 = each.value.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefix
}

resource "azurerm_subnet_nat_gateway_association" "nat_gateway_association" {
  for_each = var.subnetwithNatGateways

  subnet_id      = azurerm_subnet.subnets[each.key].id
  nat_gateway_id = azurerm_nat_gateway.nat_gateways[each.key].id
}

resource "azurerm_network_security_group" "subnets_nsg" {
  for_each = var.subnetwithNatGateways

  name                = "${azurerm_subnet.subnets[each.key].name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "subnets_nsg_association" {
  for_each = var.subnetwithNatGateways

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.subnets_nsg[each.key].id
}
