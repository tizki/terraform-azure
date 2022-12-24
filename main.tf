terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "tf-tutorial" {
  name     = "tf-tutorial-resources"
  location = "West Europe"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "tf-tutorial" {
  name                = "acctvn"
  resource_group_name = azurerm_resource_group.tf-tutorial.name
  location            = azurerm_resource_group.tf-tutorial.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "tf-tutorial" {
   name                 = "tf-tutorial-subnet"
   resource_group_name  = azurerm_resource_group.tf-tutorial.name
   virtual_network_name = azurerm_virtual_network.tf-tutorial.name
   address_prefixes     = ["10.0.2.0/24"]
 }

 resource "azurerm_public_ip" "tf-tutorial" {
   name                         = "publicIPForLB"
   location                     = azurerm_resource_group.tf-tutorial.location
   resource_group_name          = azurerm_resource_group.tf-tutorial.name
   allocation_method            = "Static"
 }

 resource "azurerm_lb" "tf-tutorial" {
   name                = "loadBalancer"
   location            = azurerm_resource_group.tf-tutorial.location
   resource_group_name = azurerm_resource_group.tf-tutorial.name

   frontend_ip_configuration {
     name                 = "publicIPAddress"
     public_ip_address_id = azurerm_public_ip.tf-tutorial.id
   }
 }

 resource "azurerm_lb_backend_address_pool" "tf-tutorial" {
   loadbalancer_id     = azurerm_lb.tf-tutorial.id
   name                = "BackEndAddressPool"
 }

 resource "azurerm_network_interface" "tf-tutorial" {
   count               = 2
   name                = "acctni${count.index}"
   location            = azurerm_resource_group.tf-tutorial.location
   resource_group_name = azurerm_resource_group.tf-tutorial.name

   ip_configuration {
     name                          = "testConfiguration"
     subnet_id                     = azurerm_subnet.tf-tutorial.id
     private_ip_address_allocation = "Dynamic"
   }
 }

 resource "azurerm_managed_disk" "tf-tutorial" {
   count                = 2
   name                 = "datadisk_existing_${count.index}"
   location             = azurerm_resource_group.tf-tutorial.location
   resource_group_name  = azurerm_resource_group.tf-tutorial.name
   storage_account_type = "Standard_LRS"
   create_option        = "Empty"
   disk_size_gb         = "1023"
 }

 resource "azurerm_availability_set" "avset" {
   name                         = "avset"
   location                     = azurerm_resource_group.tf-tutorial.location
   resource_group_name          = azurerm_resource_group.tf-tutorial.name
   platform_fault_domain_count  = 2
   platform_update_domain_count = 2
   managed                      = true
 }

 resource "azurerm_virtual_machine" "tf-tutorial" {
   count                 = 1
   name                  = "acctvm${count.index}"
   location              = azurerm_resource_group.tf-tutorial.location
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = azurerm_resource_group.tf-tutorial.name
   network_interface_ids = [element(azurerm_network_interface.tf-tutorial.*.id, count.index)]
   vm_size               = "Standard_DS1_v2"
   delete_os_disk_on_termination = true
   delete_data_disks_on_termination = true

   storage_image_reference {
     publisher = "Canonical"
     offer     = "UbuntuServer"
     sku       = "18.04-LTS"
     version   = "latest"
   }

   storage_os_disk {
     name              = "myosdisk${count.index}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }
   
   os_profile {
     computer_name  = "hostname"
     admin_username = "testadmin"
     admin_password = "Password1234!"
   }

  os_profile_linux_config {
     disable_password_authentication = false
   }
 }