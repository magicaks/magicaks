provider "azurerm" {
    version = "~>1.8"
}

terraform {
  backend "azurerm" {
    container_name = "tfstate"
    key = "magicaks-adhoc"
    storage_account_name = "longlasting"
  }
}

resource "azurerm_resource_group" "magicakssupport" {
  name     = "magicaks-support"
  location = var.location
}

resource "azurerm_public_ip" "bastionpublicip" {
  name                = "bastionpublicip"
  location            = var.location
  resource_group_name = azurerm_resource_group.magicakssupport.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "bastionnic" {
  name                = "bastionnic"
  location            = azurerm_resource_group.magicakssupport.location
  resource_group_name = azurerm_resource_group.magicakssupport.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.bastionpublicip.id
  }
}


resource "azurerm_virtual_machine" "bastionbox" {
  name                = "bastionbox"
  resource_group_name = azurerm_resource_group.magicakssupport.name
  location            = azurerm_resource_group.magicakssupport.location
  vm_size                = "Standard_F2"
  network_interface_ids = [
    azurerm_network_interface.bastionnic.id,
  ]

  os_profile {
    computer_name = "bastionbox"
    admin_username = "bastionbox"
  }

  os_profile_linux_config {
    disable_password_authentication = "true"
    ssh_keys {
        path = "/home/bastionbox/.ssh/authorized_keys"
        key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  storage_os_disk {
    name              = "osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}