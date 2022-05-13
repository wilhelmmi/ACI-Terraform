# Provider declaraion
terraform {
  required_providers {
    aci = {
      source = "CiscoDevNet/aci"
      version = "2.2.0"
    }
  }
}

# Provider configuration
provider "aci" {
  url      = var.aci_host
  username = var.aci_username
  password = var.aci_password
}

# Configure Variables for ACI-Tenant in terraform.tfvars file !!!

module "aci-tenat" {
  source            = "../../modules/aci-tenant"
  tenant_parameters = var.tenant_parameters

}


