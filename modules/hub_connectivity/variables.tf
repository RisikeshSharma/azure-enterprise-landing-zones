variable "workload_name" {
  type    = string
  default = "ent-core"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "hub_address_space" {
  type    = list(string)
  default = ["10.100.0.0/16"]
}

variable "hub_subnets" {
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
  type    = string
  default = "Premium"
}

variable "deploy_azure_bastion" {
  type    = bool
  default = true
}

variable "private_dns_zone_names" {
  type = map(string)
  default = {
    "blob"  = "privatelink.blob.core.windows.net"
    "vault" = "privatelink.vaultcore.azure.net"
    "sql"   = "privatelink.database.windows.net"
    "acr"   = "privatelink.azurecr.io"
  }
}

variable "tags" {
  type = map(string)
}
