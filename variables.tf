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

variable "spoke_vnets" {
  description = "Map of spoke VNets with configuration iterated via for_each and conditional peering."
  type = map(object({
    cidr_block           = list(string)
    enable_hub_peering   = bool
    allow_forwarded_traf = bool
    subnets = map(object({
      cidr_block        = list(string)
      service_endpoints = optional(list(string), [])
    }))
  }))
  default = {
    "spoke-corp-prod" = {
      cidr_block           = ["10.101.0.0/16"]
      enable_hub_peering   = true
      allow_forwarded_traf = true
      subnets = {
        "snet-workloads" = {
          cidr_block        = ["10.101.1.0/24"]
          service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"]
        }
        "snet-data" = {
          cidr_block        = ["10.101.2.0/24"]
          service_endpoints = ["Microsoft.Storage"]
        }
      }
    }
    "spoke-online-prod" = {
      cidr_block           = ["10.102.0.0/16"]
      enable_hub_peering   = true
      allow_forwarded_traf = true
      subnets = {
        "snet-ingress" = {
          cidr_block = ["10.102.1.0/24"]
        }
        "snet-app" = {
          cidr_block = ["10.102.2.0/24"]
        }
      }
    }
  }
}

variable "network_security_rules" {
  description = "List of NSG rules for dynamic security_rule block generation."
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

variable "firewall_sku_tier" {
  description = "Tier of Azure Firewall to deploy. Premium required for TLS Inspection and IDPS."
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Standard", "Premium", "Basic"], var.firewall_sku_tier)
    error_message = "Azure Firewall SKU Tier must be Standard, Premium, or Basic."
  }
}

variable "enable_cis_policy_initiative" {
  description = "Conditional toggle to assign CIS Microsoft Azure Benchmark initiative."
  type        = bool
  default     = true
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
