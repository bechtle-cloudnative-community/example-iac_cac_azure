#-Some Global Configuration-----------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # version = "=2.46.0"
    }
  }
}

provider "azurerm" {
  features {}
  tenant_id       = var.ARM_TENANT_ID
  subscription_id = var.ARM_SUBSCRIPTION_ID
  client_id       = var.ARM_CLIENT_ID
  client_secret   = var.ARM_CLIENT_SECRET
}

#-Some Stack specific Configuration-----------------------------
variable "VM_AMOUNT" {
  type        = number
  default     = 2
}


#-The Demo Stack----------------------------------------
resource "azurerm_resource_group" "tech_demo" {
  name     = "terraformer"
  location = "Germany West Central"
}

#-Virtual Network---------------
resource "azurerm_virtual_network" "tech_demo" {
  name                = "demo-network"
  resource_group_name = azurerm_resource_group.tech_demo.name
  location            = azurerm_resource_group.tech_demo.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "tech_demo" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.tech_demo.name
  virtual_network_name = azurerm_virtual_network.tech_demo.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vm_mgmt" {
  name                 = "PublicIPForCaC-${count.index}"
  location             = azurerm_resource_group.tech_demo.location
  resource_group_name  = azurerm_resource_group.tech_demo.name
  allocation_method    = "Static"
  count                = var.VM_AMOUNT
}

resource "azurerm_network_interface" "tech_demo" {
  name                = "demo-nic-${count.index}"
  resource_group_name = azurerm_resource_group.tech_demo.name
  location            = azurerm_resource_group.tech_demo.location
  count               = var.VM_AMOUNT
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tech_demo.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_mgmt[count.index].id
  }
}

#-Virtual Machines------------------
resource "azurerm_availability_set" "tech_demo" {
  name                = "techdemo-aset"
  location            = azurerm_resource_group.tech_demo.location
  resource_group_name = azurerm_resource_group.tech_demo.name
  platform_fault_domain_count = 2

  tags = {
    environment = "Production"
  }
}

resource "azurerm_linux_virtual_machine" "tech_demo" {
  name                = "demo-machine-${count.index}"
  resource_group_name = azurerm_resource_group.tech_demo.name
  location            = azurerm_resource_group.tech_demo.location
  availability_set_id = azurerm_availability_set.tech_demo.id
  size                = "Standard_B1ms"
  admin_username      = "ubuntu"
  count               = var.VM_AMOUNT
  network_interface_ids = [
    azurerm_network_interface.tech_demo[count.index].id,
  ]

  admin_ssh_key {
    username   = "ubuntu"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

}

#-Central Storage--------------------
resource "azurerm_managed_disk" "tech_demo" {
  name                 = "central_storage"
  resource_group_name  = azurerm_resource_group.tech_demo.name
  location             = azurerm_resource_group.tech_demo.location
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"
  # shared               = true
  max_shares           = var.VM_AMOUNT
  tier                 = "P30"
}

resource "azurerm_virtual_machine_data_disk_attachment" "tech_demo" {
  managed_disk_id    = azurerm_managed_disk.tech_demo.id
  virtual_machine_id = azurerm_linux_virtual_machine.tech_demo[count.index].id
  lun                = "0"
  caching            = "None"
  count              = var.VM_AMOUNT
}


#-Load Balancing-------------------
resource "azurerm_public_ip" "tech_demo" {
  name                = "PublicIPForLB"
  location             = azurerm_resource_group.tech_demo.location
  resource_group_name  = azurerm_resource_group.tech_demo.name
  allocation_method   = "Static"
}

# resource "azurerm_lb" "tech_demo" {
#   name                 = "TestLoadBalancer"
#   location             = azurerm_resource_group.tech_demo.location
#   resource_group_name  = azurerm_resource_group.tech_demo.name

#   frontend_ip_configuration {
#     name                 = "PublicIPAddress"
#     public_ip_address_id = azurerm_public_ip.tech_demo.id
#   }
# }

# resource "azurerm_lb_probe" "tech_demo" {
#   resource_group_name = azurerm_resource_group.tech_demo.name
#   loadbalancer_id     = azurerm_lb.tech_demo.id
#   name                = "http-running-probe"
#   port                = 5000
#   protocol            = "tcp"
# }

# resource "azurerm_lb_backend_address_pool" "tech_demo" {
#   loadbalancer_id = azurerm_lb.tech_demo.id
#   name            = "BackEndAddressPool"
# }

# resource "azurerm_network_interface_backend_address_pool_association" "tech_demo" {
#   network_interface_id    = azurerm_network_interface.tech_demo[count.index].id
#   ip_configuration_name   = "internal"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.tech_demo.id
#   count                   = var.VM_AMOUNT
# }

# resource "azurerm_lb_rule" "tech_demo" {
#   resource_group_name            = azurerm_resource_group.tech_demo.name
#   loadbalancer_id                = azurerm_lb.tech_demo.id
#   name                           = "LBRule"
#   protocol                       = "Tcp"
#   frontend_port                  = 80
#   backend_port                   = 5000
#   backend_address_pool_ids       = [azurerm_lb_backend_address_pool.tech_demo.id]
#   probe_id                       = azurerm_lb_probe.tech_demo.id
#   frontend_ip_configuration_name = "PublicIPAddress"
# }




#-Some usefull Outputs---------------------
output vm_mgmt_ips {
  value       = azurerm_linux_virtual_machine.tech_demo.*.public_ip_addresses
}

# output lb_ip {
#   value       = azurerm_public_ip.tech_demo.ip_address
# }


#-------------------------------------------------------