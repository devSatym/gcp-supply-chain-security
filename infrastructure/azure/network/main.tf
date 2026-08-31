locals {
  tags = merge(
    var.tags,
    {
      environment = var.environment
      owner       = var.owner
      project     = var.project_label
      cost_center = var.cost_center
      managed_by  = "terraform"
    }
  )
}

# The workload resource group belongs to the network module so the later AKS,
# registry, and observability modules can share a single explicit boundary.
resource "azurerm_resource_group" "workload" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers
  tags                = local.tags
}

# AKS nodes are intentionally separate from the API-server subnet. Do not add
# a delegation to this subnet: AKS node pools require an ordinary subnet.
resource "azurerm_subnet" "aks_nodes" {
  name                 = var.aks_nodes_subnet_name
  resource_group_name  = azurerm_resource_group.workload.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_nodes_subnet_address_prefixes

  default_outbound_access_enabled = false
}

# AKS API Server VNet Integration requires a dedicated, delegated subnet.
resource "azurerm_subnet" "aks_api_server" {
  name                 = var.aks_api_server_subnet_name
  resource_group_name  = azurerm_resource_group.workload.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aks_api_server_subnet_address_prefixes

  default_outbound_access_enabled = false

  delegation {
    name = "aks-api-server"

    service_delegation {
      name = "Microsoft.ContainerService/managedClusters"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# This subnet is reserved for Private Endpoints owned by later modules (ACR,
# Key Vault, Event Hubs, and storage). Private Endpoint policies remain
# disabled so those endpoint resources can be created without a subnet change.
resource "azurerm_subnet" "private_endpoints" {
  name                 = var.private_endpoints_subnet_name
  resource_group_name  = azurerm_resource_group.workload.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.private_endpoints_subnet_address_prefixes

  default_outbound_access_enabled               = false
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = false
}

# Function VNet integration requires a Microsoft.Web/serverFarms delegation.
resource "azurerm_subnet" "functions" {
  name                 = var.functions_subnet_name
  resource_group_name  = azurerm_resource_group.workload.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.functions_subnet_address_prefixes

  default_outbound_access_enabled = false

  delegation {
    name = "functions-vnet-integration"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

# The runner is deliberately isolated from AKS nodes and has no public IP.
# It reaches GitHub and package registries only through the controlled NAT
# gateway, while private DNS resolves AKS and Private Link endpoints.
resource "azurerm_subnet" "private_runner" {
  name                 = var.private_runner_subnet_name
  resource_group_name  = azurerm_resource_group.workload.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.private_runner_subnet_address_prefixes

  default_outbound_access_enabled = false
  service_endpoints               = ["Microsoft.Storage"]
}

resource "azurerm_network_security_group" "aks_nodes" {
  name                = "${var.vnet_name}-aks-nodes-nsg"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags

  # Azure's default NSG rules already deny all unsolicited inbound traffic.
  # This explicit rule makes the no-public-node-administration boundary clear.
  # Operator jump-host access, when supplied, must win the explicit deny below.
  dynamic "security_rule" {
    for_each = var.owner_ssh_allow_cidr != null ? [1] : []
    content {
      name                       = "AllowSSHFromOwner"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefixes    = [var.owner_ssh_allow_cidr]
      destination_address_prefix = "*"
    }
  }

  security_rule {
    name                       = "DenySSHFromInternet"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyRDPFromInternet"
    priority                   = 401
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "functions" {
  name                = "${var.vnet_name}-functions-nsg"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "${var.vnet_name}-private-endpoints-nsg"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags
}

resource "azurerm_network_security_group" "private_runner" {
  name                = "${var.vnet_name}-private-runner-nsg"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags

  # There is no operational inbound path to the runner. Azure Run Command
  # uses the VM agent through the control plane rather than SSH/RDP.
  security_rule {
    name                       = "DenySSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyRDP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                   = "AllowAzureDNS"
    priority               = 100
    direction              = "Outbound"
    access                 = "Allow"
    protocol               = "*"
    source_port_range      = "*"
    destination_port_range = "53"
    source_address_prefix  = "*"
    # Azure permits AzurePlatformDNS only in a deny rule. Use its documented
    # resolver IP here so the explicit outbound deny-all rule cannot block DNS.
    destination_address_prefix = "168.63.129.16"
  }

  security_rule {
    name                       = "AllowPrivateHttps"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowInternetHttps"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  security_rule {
    name                       = "DenyOtherOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks_nodes.id
}

resource "azurerm_subnet_network_security_group_association" "functions" {
  subnet_id                 = azurerm_subnet.functions.id
  network_security_group_id = azurerm_network_security_group.functions.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_subnet_network_security_group_association" "private_runner" {
  subnet_id                 = azurerm_subnet.private_runner.id
  network_security_group_id = azurerm_network_security_group.private_runner.id
}

# A Standard, static public IP is used only by the NAT Gateway. Nodes and pods
# receive no public IPs; their controlled outbound traffic is SNATed here.
resource "azurerm_public_ip" "nat" {
  name                = "${var.vnet_name}-nat-pip"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "main" {
  name                    = "${var.vnet_name}-nat"
  location                = azurerm_resource_group.workload.location
  resource_group_name     = azurerm_resource_group.workload.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = var.nat_gateway_idle_timeout_in_minutes
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aks_nodes" {
  subnet_id      = azurerm_subnet.aks_nodes.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

resource "azurerm_subnet_nat_gateway_association" "functions" {
  count = var.attach_nat_gateway_to_functions ? 1 : 0

  subnet_id      = azurerm_subnet.functions.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

resource "azurerm_subnet_nat_gateway_association" "private_runner" {
  count = var.attach_nat_gateway_to_private_runner ? 1 : 0

  subnet_id      = azurerm_subnet.private_runner.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# Pre-create private DNS zones and VNet links used by later Private Endpoint
# modules. AKS itself uses its managed "System" private DNS zone by default;
# private runners still need routing and DNS forwarding into this VNet.
resource "azurerm_private_dns_zone" "private_link" {
  for_each = toset(var.private_dns_zone_names)

  name                = each.value
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_link" {
  for_each = azurerm_private_dns_zone.private_link

  name                  = "${var.vnet_name}-${replace(each.key, ".", "-")}-link"
  resource_group_name   = azurerm_resource_group.workload.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.tags
}

# New NSG flow logs are retired in Azure. VNet flow logs are the supported
# target, but remain opt-in because their availability/permissions vary by
# subscription and they create a lifecycle rule on the dedicated storage account.
resource "azurerm_network_watcher" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name                = "${var.vnet_name}-network-watcher"
  location            = azurerm_resource_group.workload.location
  resource_group_name = azurerm_resource_group.workload.name
  tags                = local.tags
}

# Semgrep's generic rule rejects the trusted-services exception. Azure Network
# Watcher requires it to write VNet flow logs to a firewall-protected storage
# account; Microsoft documents this exact exception. This account is dedicated
# to flow logs and is never reused for workload data.
# nosemgrep: terraform.azure.security.storage.storage-allow-microsoft-service-bypass.storage-allow-microsoft-service-bypass
# Semgrep recognizes only the legacy inline queue_properties block. Logging is
# configured by azurerm_storage_account_queue_properties below, which is the
# supported AzureRM v4 resource.
resource "azurerm_storage_account" "flow_logs" { # nosemgrep
  count = var.enable_flow_logs ? 1 : 0

  name                     = var.flow_logs_storage_account_name
  resource_group_name      = azurerm_resource_group.workload.name
  location                 = azurerm_resource_group.workload.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.flow_logs_storage_account_replication_type

  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  # Network Watcher is a trusted Azure service. Do not reuse this account for
  # another workload because the Flow Log resource manages its lifecycle rule.
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.flow_logs_storage_account_name != null && can(regex("^[a-z0-9]{3,24}$", var.flow_logs_storage_account_name))
      error_message = "enable_flow_logs requires flow_logs_storage_account_name to be a globally unique 3-24 character lowercase alphanumeric name."
    }
  }
}

resource "azurerm_storage_account_queue_properties" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  storage_account_id = azurerm_storage_account.flow_logs[0].id

  logging {
    version               = "1.0"
    delete                = true
    read                  = true
    write                 = true
    retention_policy_days = 30
  }
}

resource "azurerm_network_watcher_flow_log" "vnet" {
  count = var.enable_flow_logs ? 1 : 0

  name                 = "${var.vnet_name}-vnet-flow-log"
  network_watcher_name = azurerm_network_watcher.flow_logs[0].name
  resource_group_name  = azurerm_network_watcher.flow_logs[0].resource_group_name
  target_resource_id   = azurerm_virtual_network.main.id
  storage_account_id   = azurerm_storage_account.flow_logs[0].id
  enabled              = true
  version              = 2
  tags                 = local.tags

  retention_policy {
    enabled = true
    days    = var.flow_logs_retention_days
  }
}
