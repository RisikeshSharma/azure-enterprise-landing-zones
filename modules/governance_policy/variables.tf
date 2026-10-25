variable "enforce_cis_benchmark" {
  type    = bool
  default = true
}

variable "target_management_group_id" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = "eastus"
}
