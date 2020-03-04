resource "azurerm_resource_group" "longlasting" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "magicaks-vnet"
  location            = azurerm_resource_group.longlasting.location
  resource_group_name = azurerm_resource_group.longlasting.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "k8s-subnet" {
  name                 = "k8s-subnet"
  resource_group_name  = azurerm_resource_group.longlasting.name
  address_prefix       = "10.1.2.0/24"
  virtual_network_name = azurerm_virtual_network.vnet.name
  service_endpoints = ["Microsoft.KeyVault", "Microsoft.ServiceBus", 
                       "Microsoft.Sql", "Microsoft.ContainerRegistry",
                       "Microsoft.Storage"]
  route_table_id    = "/subscriptions/b6a69b21-5dea-4475-9cd5-e9f2f8eb1e27/resourceGroups/magicaks-longlasting/providers/Microsoft.Network/routeTables/subnet-route-table"
}

resource "azurerm_route_table" "subnet_route_table" {
  name                          = "subnet-route-table"
  location                      = azurerm_resource_group.longlasting.location
  resource_group_name           = azurerm_resource_group.longlasting.name
  disable_bgp_route_propagation = false

  route {
    name           = "route1"
    address_prefix = "10.1.2.0/24"
    next_hop_type  = "VnetLocal"
  }
  
  route {
      name = "fw"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "VirtualAppliance"
      next_hop_in_ip_address = azurerm_firewall.magicaksfirewall.ip_configuration[0].private_ip_address
  }

  tags = {
    environment = "Development"
  }
}

resource "azurerm_subnet_route_table_association" "routetblassociation" {
  subnet_id      = azurerm_subnet.k8s-subnet.id
  route_table_id = azurerm_route_table.subnet_route_table.id
}

resource "azurerm_subnet" "fwsubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.longlasting.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.1.1.0/24"
}

resource "azurerm_public_ip" "fwip" {
  name                = "fwpublicip"
  location            = azurerm_resource_group.longlasting.location
  resource_group_name = azurerm_resource_group.longlasting.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "magicaksfirewall" {
  name                = "MagicAKSFirewall"
  location            = azurerm_resource_group.longlasting.location
  resource_group_name = azurerm_resource_group.longlasting.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fwsubnet.id
    public_ip_address_id = azurerm_public_ip.fwip.id
  }
}

resource "azurerm_firewall_network_rule_collection" "magicaksrules" {
  name                = "OutboundRules"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = azurerm_resource_group.longlasting.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "tunnel front"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "9000", #tunnel front
      "22"
    ]

    destination_addresses = [
      "*",
    ]

    protocols = [
      "TCP",
    ]
  }

  rule {
    name = "https"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "80",
      "443"
    ]

    destination_addresses = [
      "*",
    ]

    protocols = [
      "TCP",
    ]
  }
  
  rule {
    name = "udp"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "53", # DNS
      "123" #NTP
    ]

    destination_addresses = [
      "*",
    ]

    protocols = [
      "UDP",
    ]
  }
  
  rule {
    name = "fileshare"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "445",
    ]

    destination_addresses = [
      "*",
    ]

    protocols = [
      "TCP",
    ]
  }
}

resource "azurerm_firewall_application_rule_collection" "AKS_Global_Required" {
  name                = "AKS_Global_Required"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = azurerm_resource_group.longlasting.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "required"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
        "aksrepos.azurecr.io",
        "*blob.core.windows.net",
        "mcr.microsoft.com",
        "*cdn.mscr.io",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "ntp.ubuntu.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net"
    ]

    protocol {
      port = "443"
      type = "Https"
    }

    protocol {
      port = "80"
      type = "Http"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "AKS_Cloud_Specific_Required" {
  name                = "AKS_Cloud_Specific_Required"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = azurerm_resource_group.longlasting.name
  priority            = 200
  action              = "Allow"

  rule {
    name = "required"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
      "*.hcp.${var.location}.azmk8s.io",
      "*.tun.${var.location}.azmk8s.io"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "UbuntuUpdates" {
  name                = "UbuntuUpdates"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = azurerm_resource_group.longlasting.name
  priority            = 300
  action              = "Allow"

  rule {
    name = "ubuntu"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
      "security.ubuntu.com",
      "azure.archive.ubuntu.com",
      "changelogs.ubuntu.com"
    ]

    protocol {
      port = "443"
      type = "Https"
    }

    protocol {
      port = "80"
      type = "Http"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "AKS_Azure_Monitor_Required" {
  name                = "AKS_Azure_Monitor_Required"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = azurerm_resource_group.longlasting.name
  priority            = 400
  action              = "Allow"

  rule {
    name = "azure_monitor"

    source_addresses = [
      "*",
    ]

    target_fqdns = [
      "dc.services.visualstudio.com",
      "*.ods.opinsights.azure.com",
      "*.oms.opinsights.azure.com",
      "*.microsoftonline.com",
      "*.monitoring.azure.com"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

resource "azurerm_firewall_application_rule_collection" "AKS_For_Public_Container_Registries_Required" {
  name                = "AKS_For_Public_Container_Registries_Required"
  azure_firewall_name = azurerm_firewall.magicaksfirewall.name
  resource_group_name = azurerm_resource_group.longlasting.name
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
  resource_group_name = azurerm_resource_group.longlasting.name
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
  resource_group_name = azurerm_resource_group.longlasting.name
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
  resource_group_name = azurerm_resource_group.longlasting.name
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
