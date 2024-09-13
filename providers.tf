terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = "3.4"
    }
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.5"
    }
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.1"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.3"
    }
    vault = {
      source = "hashicorp/vault"
      version = "~> 3"
    }
  }
}

provider "boundary" {
  addr  = var.boundary_address
  token = var.boundary_token
}

provider "dns" {
  update {
    gssapi {}
  }       
}