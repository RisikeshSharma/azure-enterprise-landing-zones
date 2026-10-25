variable "root_management_group_id" {
  description = "Unique identifier for the top-level root management group."
  type        = string
  default     = "mg-enterprise-root"
}

variable "root_management_group_name" {
  description = "Display name for the top-level root management group."
  type        = string
  default     = "Enterprise Cloud Architecture Root"
}

variable "tenant_root_group_id" {
  description = "Optional Tenant Root Group ID to nest under."
  type        = string
  default     = ""
}

variable "core_management_groups" {
  description = "Level 2 CAF Management Groups."
  type = map(object({
    display_name = string
  }))
  default = {
    "platform" = {
      display_name = "Platform"
    }
    "landing-zones" = {
      display_name = "Landing Zones"
    }
    "sandbox" = {
      display_name = "Sandbox"
    }
    "decommissioned" = {
      display_name = "Decommissioned"
    }
  }
}

variable "platform_child_groups" {
  description = "Platform child management groups."
  type = map(object({
    display_name = string
  }))
  default = {
    "connectivity" = {
      display_name = "Connectivity"
    }
    "identity" = {
      display_name = "Identity"
    }
    "management" = {
      display_name = "Management"
    }
  }
}

variable "landing_zone_child_groups" {
  description = "Landing Zone child management groups."
  type = map(object({
    display_name = string
  }))
  default = {
    "corp" = {
      display_name = "Corporate (Intranet Only)"
    }
    "online" = {
      display_name = "Online (Public Facing)"
    }
  }
}
