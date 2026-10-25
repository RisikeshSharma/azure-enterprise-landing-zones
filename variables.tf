variable "environment" {
  description = "Target deployment environment (e.g. prod, staging, dev)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Primary Azure region for all landing zone platform resources."
  type        = string
  default     = "eastus"
}

variable "workload_name" {
  description = "Identifier prefix for naming convention."
  type        = string
  default     = "ent-core"
}

variable "organization_name" {
  description = "Organization name for management group root display."
  type        = string
  default     = "Enterprise Cloud"
}

variable "deploy_management_groups" {
  description = "Toggle management group deployment (requires Tenant Root permissions)."
  type        = bool
  default     = false
}

variable "hub_vnet_cidr" {
  description = "Address space for the central Connectivity Hub VNet."
  type        = list(string)
  default     = ["10.100.0.0/16"]
}

variable "hub_subnets" {
  description = "Map of subnets within the Hub VNet using dynamic for_each iteration."
  type = map(object({
    address_prefixes                          = list(string)
    service_endpoints                         = optional(list(string), [])
    private_endpoint_network_policies_enabled = optional(bool, true)
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }))
  }))
  default = {
    "AzureFirewallSubnet" = {
      address_prefixes = ["10.100.0.0/24"]
    }
    "AzureFirewallManagementSubnet" = {
      address_prefixes = ["10.100.1.0/24"]
    }
    "GatewaySubnet" = {
      address_prefixes = ["10.100.2.0/24"]
    }
    "AzureBastionSubnet" = {
      address_prefixes = ["10.100.3.0/24"]
    }
    "snet-management" = {
      address_prefixes  = ["10.100.10.0/24"]
      service_endpoints = ["Microsoft.KeyVault", "Microsoft.Storage"]
    }
    "snet-private-endpoints" = {
      address_prefixes                          = ["10.100.20.0/24"]
      private_endpoint_network_policies_enabled = true
    }
  }
}

variable "firewall_sku_tier" {
  description = "Tier of Azure Firewall to deploy. Premium required for TLS Inspection and IDPS."
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Standard", "Premium", "Basic"], var.firewall_sku_tier)
    error_message = "Azure Firewall SKU Tier must be Standard, Premium, or Basic."
  }
}

variable "deploy_azure_bastion" {
  description = "Toggle deployment of Azure Bastion Host."
  type        = bool
  default     = true
}

variable "spoke_landing_zones" {
  description = "Map of Spoke Landing Zones instantiated dynamically via for_each."
  type = map(object({
    address_space = list(string)
    subnets = map(object({
      address_prefixes                          = list(string)
      service_endpoints                         = optional(list(string), [])
      private_endpoint_network_policies_enabled = optional(bool, true)
    }))
  }))
  default = {
    "spoke-corp-prod" = {
      address_space = ["10.101.0.0/16"]
      subnets = {
        "snet-workloads" = {
          address_prefixes  = ["10.101.1.0/24"]
          service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"]
        }
        "snet-data" = {
          address_prefixes  = ["10.101.2.0/24"]
          service_endpoints = ["Microsoft.Storage"]
        }
      }
    }
    "spoke-online-prod" = {
      address_space = ["10.102.0.0/16"]
      subnets = {
        "snet-ingress" = {
          address_prefixes = ["10.102.1.0/24"]
        }
        "snet-app" = {
          address_prefixes  = ["10.102.2.0/24"]
          service_endpoints = ["Microsoft.KeyVault"]
        }
      }
    }
  }
}

variable "default_spoke_security_rules" {
  description = "List of default security rules iterated dynamically across spoke NSGs."
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
    description                = optional(string)
  }))
  default = [
    {
      name                       = "DenyAllInboundInternet"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
      description                = "Zero-trust default deny rule for inbound internet traffic."
    },
    {
      name                       = "AllowCorpVNetInbound"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
      description                = "Allow intra-VNet secure HTTPS communication."
    }
  ]
}

variable "enable_cis_policy_initiative" {
  description = "Conditional toggle to assign CIS Microsoft Azure Benchmark initiative."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Standard resource tags for cost allocation and governance."
  type        = map(string)
  default = {
    Architecture = "Azure-Enterprise-Landing-Zones"
    ManagedBy    = "Terraform"
    SecurityTier = "Zero-Trust"
    Owner        = "Rishikesh Sharma"
  }
}
