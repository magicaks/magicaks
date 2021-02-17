resource "azurerm_virtual_network" "vnet" {
  name                = "magicaks-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "k8s-subnet" {
  name                 = "k8s-subnet"
  resource_group_name  = var.resource_group_name
  address_prefixes       = ["10.1.2.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  service_endpoints = ["Microsoft.KeyVault", "Microsoft.ServiceBus", 
                       "Microsoft.Sql", "Microsoft.ContainerRegistry",
                       "Microsoft.Storage"]
}

resource "azurerm_subnet" "acisubnet" {
  name                 = "acisubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = ["10.1.3.0/24"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
  service_endpoints = [ "Microsoft.Sql", "Microsoft.ContainerRegistry"]

}

resource "azurerm_subnet" "adhocsubnet" {
  name                 = "adhocsubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = ["10.1.4.0/24"]
}

resource "azurerm_network_profile" "aciprofile" {
  name                = "aciprofile"
  location            = var.location
  resource_group_name = var.resource_group_name

  container_network_interface {
    name = "acinic"

    ip_configuration {
      name      = "aciipconfig"
      subnet_id = azurerm_subnet.acisubnet.id
    }
  }
}

resource "azurerm_route_table" "subnet_route_table" {
  name                          = "subnet-route-table"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  disable_bgp_route_propagation = false

  route {
    name           = "internet"
    address_prefix = "${azurerm_public_ip.fwip.ip_address}/32"
    next_hop_type  = "Internet"
  }
  
  route {
      name = "fw"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "VirtualAppliance"
      next_hop_in_ip_address = azurerm_firewall.magicaksfirewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "routetblassociation" {
  subnet_id      = azurerm_subnet.k8s-subnet.id
  route_table_id = azurerm_route_table.subnet_route_table.id
}

resource "azurerm_subnet" "fwsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "fwip" {
  name                = "fwpublicip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "magicaksfirewall" {
  name                = "${var.cluster_name}Firewall"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fwsubnet.id
    public_ip_address_id = azurerm_public_ip.fwip.id
  }
}

resource "azurerm_firewall_network_rule_collection" "magicaksrules" {
  name                = "OutboundRules"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = var.resource_group_name
  priority            = 100
  action              = "Allow"

  rule {
    name = "TCP Rules"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "9000",
      "443",
      "445",
      "22",
      "80"
    ]

    destination_addresses = [
      "*",
    ]

    protocols = [
      "TCP",
    ]
  }

  rule {
    name = "UDP Rules"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "1194",
      "123",
      "53"
    ]

    destination_addresses = [
      "*",
    ]

    protocols = [
      "UDP"
    ]
  }
}

resource "azurerm_firewall_application_rule_collection" "AKS_Global_Required" {
  name                = "AKS_Global_Required"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = var.resource_group_name
  priority            = 100
  action              = "Allow"

  rule {
    name = "required"

    source_addresses = [
      "*",
    ]

    fqdn_tags = [ "AzureKubernetesService" ]
  }
}

resource "azurerm_firewall_application_rule_collection" "AKS_For_Public_Container_Registries_Required" {
  name                = "AKS_For_Public_Container_Registries_Required"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = var.resource_group_name
  priority            = 500
  action              = "Allow"

  rule {
    name = "registries"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
        "*auth.docker.io",
        "*cloudflare.docker.io",
        "*cloudflare.docker.com",
        "*registry-1.docker.io",
        "apt.dockerproject.org",
        "gcr.io",
        "storage.googleapis.com",
        "*.quay.io",
        "quay.io",
        "*.cloudfront.net",
        "*.azurecr.io",
        "*.gk.azmk8s.io"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "Flux" {
  name                = "Flux"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = var.resource_group_name
  priority            = 600
  action              = "Allow"

  rule {
    name = "flux"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
        "*.github.com"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "KeyVault" {
  name                = "KeyVault"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = var.resource_group_name
  priority            = 700
  action              = "Allow"

  rule {
    name = "kv"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
        "*.vault.azure.net"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "AzurePolicy" {
  name                = "AzurePolicy"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = var.resource_group_name
  priority            = 800
  action              = "Allow"

  rule {
    name = "azurepolicy"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
        "gov-prod-policy-data.trafficmanager.net",
        "raw.githubusercontent.com",
        "*.gk.azmk8s.io",
        "dc.services.visualstudio.com"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}
