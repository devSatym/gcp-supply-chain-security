locals {
  runner_username = "gha"
}

resource "azurerm_network_interface" "this" {
  name                = "${var.name_prefix}-private-runner-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                            = "${var.name_prefix}-private-runner"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.this.id]
  encryption_at_host_enabled      = true
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  patch_mode                      = "AutomaticByPlatform"
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  boot_diagnostics {}

  # Runner registration is deliberately excluded from Terraform because the
  # GitHub registration token is short-lived and must never enter state.
  custom_data = base64encode(<<-CLOUD_INIT
    #cloud-config
    runcmd:
      - useradd --create-home --shell /bin/bash ${local.runner_username} || true
  CLOUD_INIT
  )
}
