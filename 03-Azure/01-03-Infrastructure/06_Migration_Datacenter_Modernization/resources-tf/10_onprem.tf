## RESOURCE GROUP

resource "azurerm_resource_group" "onprem" {
  name     = "${var.global_label}-${var.group_label}-onprem-rg"
  location = var.location
}

## Start network resources

resource "azurerm_virtual_network" "onprem" {
  name                = "onprem-vnet-${var.group_label}"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "onprem-workload" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.onprem.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "onprem-bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.onprem.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_network_security_group" "onprem" {
  name                = "onprem-nsg-${var.group_label}"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
}

resource "azurerm_network_security_rule" "http" {
  name                        = "AllowHTTP"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80","443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.onprem.name
  network_security_group_name = azurerm_network_security_group.onprem.name
}

resource "azurerm_subnet_network_security_group_association" "onprem-nsg-workload-subnet" {
  subnet_id                 = azurerm_subnet.onprem-workload.id
  network_security_group_id = azurerm_network_security_group.onprem.id
}

resource "azurerm_public_ip" "onprem-bastion" {
  name                = "AzureBastion-pip"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "onprem" {
  name                = "onprem-bastion-${var.group_label}"
  sku                 = "Basic"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  ip_configuration {
    name                 = "onprem-bastion-configuration"
    subnet_id            = azurerm_subnet.onprem-bastion.id
    public_ip_address_id = azurerm_public_ip.onprem-bastion.id
  }
}

data "azurerm_client_config" "current" {}

# Random 8-character string to include in the key vault name, to prevent running into deleted but not purged KVs
resource "random_string" "keyvault" {
  length  = 8
  special = false
  lower = true
  upper = false
  numeric = false
}

resource "azurerm_key_vault" "onprem" {
  name                = "${var.group_label}-${random_string.keyvault.result}-kv"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]
  }
}

# Add a secret
resource "azurerm_key_vault_secret" "adminpass" {
  name         = "adminpassword"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.onprem.id
}

## End network resources

## Start host resources
# Create the on-premises hosts

locals {
  deploymentscript_winweb1   = "https://raw.githubusercontent.com/latj/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Datacenter_Modernization/resources/deploy.ps1"
  deploymentscript_discovery = "https://raw.githubusercontent.com/latj/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Datacenter_Modernization/resources/discovery.ps1"
  deploymentscript_migration = "https://raw.githubusercontent.com/latj/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Datacenter_Modernization/resources/migration.ps1"  
  linux_customdata = file("../resources/cloud.cfg")
}

resource "azurerm_network_interface" "winweb1" {
  name                = "winweb1-nic"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.onprem-workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.5"
  }
}

resource "azurerm_windows_virtual_machine" "winweb1" {
  name                            = "winweb1"
  resource_group_name             = azurerm_resource_group.onprem.name
  location                        = azurerm_resource_group.onprem.location
  size                            = var.workload_host_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  identity {
    type = "SystemAssigned"
  }
  network_interface_ids = [
    azurerm_network_interface.winweb1.id
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-smalldisk-g2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
  }
  boot_diagnostics {}
  vm_agent_platform_updates_enabled = true
}

resource "azurerm_virtual_machine_extension" "winweb1-cse" {
  name                 = "winweb1-cse"
  virtual_machine_id   = azurerm_windows_virtual_machine.winweb1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
  {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server -IncludeManagementTools; powershell -ExecutionPolicy Unrestricted -File deploy.ps1",
      "fileUris": ["${local.deploymentscript_winweb1}"]
  }
SETTINGS
}

resource "azurerm_network_interface" "lnxweb1" {
  name                = "lnxweb1-nic"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.onprem-workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.4"
  }
}

resource "azurerm_linux_virtual_machine" "lnxweb1" {
  name                            = "lnxweb1"
  resource_group_name             = azurerm_resource_group.onprem.name
  location                        = azurerm_resource_group.onprem.location
  size                            = var.workload_host_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  custom_data = base64encode(local.linux_customdata)
  identity {
    type = "SystemAssigned"
  }
  network_interface_ids = [
    azurerm_network_interface.lnxweb1.id
  ]

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "86-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
  }
  boot_diagnostics {}
}

resource "azurerm_virtual_machine_extension" "lnxweb1-cse" {
  name                 = "lnxweb1-cse"
  virtual_machine_id   = azurerm_linux_virtual_machine.lnxweb1.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"
  settings = <<SETTINGS
  {
      "commandToExecute": "sudo firewall-cmd --zone=public --add-port=80/tcp --permanent && sudo firewall-cmd --reload"
  }
SETTINGS
}

resource "azurerm_network_interface" "discovery" {
  name                = "discovery-nic"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.onprem-workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.6"
  }
}

resource "azurerm_windows_virtual_machine" "discovery" {
  name                            = "discovery"
  resource_group_name             = azurerm_resource_group.onprem.name
  location                        = azurerm_resource_group.onprem.location
  size                            = var.migration_host_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  identity {
    type = "SystemAssigned"
  }
  network_interface_ids = [
    azurerm_network_interface.discovery.id
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-smalldisk-g2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
  }
  boot_diagnostics {}
  vm_agent_platform_updates_enabled = true
}

resource "azurerm_virtual_machine_extension" "discovery-cse" {
  name                 = "discovery-cse"
  virtual_machine_id   = azurerm_windows_virtual_machine.discovery.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
  {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server -IncludeManagementTools; powershell -ExecutionPolicy Unrestricted -File discovery.ps1",
      "fileUris": ["${local.deploymentscript_discovery}"]
  }
SETTINGS
}

resource "azurerm_network_interface" "migration" {
  name                = "migration-nic"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.onprem-workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.7"
  }
}

resource "azurerm_windows_virtual_machine" "migration" {
  name                            = "migration"
  resource_group_name             = azurerm_resource_group.onprem.name
  location                        = azurerm_resource_group.onprem.location
  size                            = var.migration_host_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  identity {
    type = "SystemAssigned"
  }
  network_interface_ids = [
    azurerm_network_interface.migration.id
  ]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-datacenter-smalldisk-g2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
  }
  boot_diagnostics {}
  vm_agent_platform_updates_enabled = true
}

resource "azurerm_managed_disk" "migration" {
  name                 = "migration-disk1"
  location             = azurerm_resource_group.onprem.location
  resource_group_name  = azurerm_resource_group.onprem.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1024
}

resource "azurerm_virtual_machine_data_disk_attachment" "migration" {
  managed_disk_id    = azurerm_managed_disk.migration.id
  virtual_machine_id = azurerm_windows_virtual_machine.migration.id
  lun                = "1"
  caching            = "ReadWrite"
}

resource "azurerm_virtual_machine_extension" "migration-cse" {
  name                 = "migration-cse"
  virtual_machine_id   = azurerm_windows_virtual_machine.migration.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
  {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server -IncludeManagementTools; powershell -ExecutionPolicy Unrestricted -File migration.ps1",
      "fileUris": ["${local.deploymentscript_migration}"]
  }
SETTINGS
}

# Public IP for load balancer
resource "azurerm_public_ip" "onprem-lb" {
  name                = "onprem-lb-pip"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "onprem-lb-outbound" {
  name                = "onprem-lb-outbound-pip"
  location            = azurerm_resource_group.onprem.location
  resource_group_name = azurerm_resource_group.onprem.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Load balancer for all VM hosts
resource "azurerm_lb" "onprem" {
  name                = "onprem-lb"
  resource_group_name = azurerm_resource_group.onprem.name
  location            = azurerm_resource_group.onprem.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "PublicIPAddress"
    public_ip_address_id          = azurerm_public_ip.onprem-lb.id
  }

  frontend_ip_configuration {
    name                          = "OutboundPublicIPAddress"
    public_ip_address_id          = azurerm_public_ip.onprem-lb-outbound.id
  }
}

resource azurerm_lb_backend_address_pool "backend" {
  loadbalancer_id     = azurerm_lb.onprem.id
  name                = "LoadBalancerBackEndPool"
}

resource "azurerm_lb_backend_address_pool_address" "winweb1" {
  name                                = "winweb1"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.backend.id
  virtual_network_id                  = azurerm_virtual_network.onprem.id
  ip_address                          = azurerm_network_interface.winweb1.private_ip_address
}

resource "azurerm_lb_backend_address_pool_address" "lnxweb1" {
  name                                = "lnxweb1"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.backend.id
  virtual_network_id                  = azurerm_virtual_network.onprem.id
  ip_address                          = azurerm_network_interface.lnxweb1.private_ip_address
}

resource azurerm_lb_backend_address_pool "backend-outbound" {
  loadbalancer_id     = azurerm_lb.onprem.id
  name                = "LoadBalancerBackEndPoolOutbound"
}

resource "azurerm_lb_backend_address_pool_address" "winweb1-outbound" {
  name                                = "winweb1-outbound"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.backend-outbound.id
  virtual_network_id                  = azurerm_virtual_network.onprem.id
  ip_address                          = azurerm_network_interface.winweb1.private_ip_address
}

resource "azurerm_lb_backend_address_pool_address" "lnxweb1-outbound" {
  name                                = "lnxweb1-outbound"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.backend-outbound.id
  virtual_network_id                  = azurerm_virtual_network.onprem.id
  ip_address                          = azurerm_network_interface.lnxweb1.private_ip_address
}

resource "azurerm_lb_probe" "http" {
  loadbalancer_id = azurerm_lb.onprem.id
  name                = "http"
  port                = 80
  protocol            = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.onprem.id
  name                           = "myHTTPRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  idle_timeout_in_minutes        = 15
  enable_tcp_reset               = true
  disable_outbound_snat          = true
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.backend.id
  ]
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_lb_outbound_rule" "tcpoutbound" {
  name                    = "OutboundRule"
  loadbalancer_id         = azurerm_lb.onprem.id
  protocol                = "Tcp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend.id

  frontend_ip_configuration {
    name = "OutboundPublicIPAddress"
  }
}

## End host resources