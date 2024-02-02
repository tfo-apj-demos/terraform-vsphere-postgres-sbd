locals {
  #workspace_entity_name = "organization:${split("/", var.TFC_WORKSPACE_SLUG)[0]}:project:${var.TFC_PROJECT_NAME}:workspace:${var.TFC_WORKSPACE_NAME}"
}

# --- Get latest Vault image value from HCP Packer
data "hcp_packer_image" "this" {
  bucket_name    = "postgres-ubuntu-2204"
  channel        = "latest"
  cloud_provider = "vsphere"
  region         = "Datacenter"
}

# --- Retrieve IPs for use by the load balancer and Vault virtual machines
data "nsxt_policy_ip_pool" "this" {
  display_name = "10 - gcve-foundations"
}
resource "nsxt_policy_ip_address_allocation" "this" {
  display_name = "postgres"
  pool_path    = data.nsxt_policy_ip_pool.this.path
}


# --- Deploy a cluster of Vault nodes
module "postgres" {
  source  = "app.terraform.io/tfo-apj-demos/virtual-machine/vsphere"
  version = "~> 1.3"

  hostname          = "postgres-sbd"
  datacenter        = "Datacenter"
  cluster           = "cluster"
  primary_datastore = "vsanDatastore"
  folder_path       = "management"
  networks = {
    "seg-general" : "${nsxt_policy_ip_address_allocation.this.allocation_ip}/22"
  }
  dns_server_list = [
    "172.21.15.150",
    "10.10.0.8"
  ]
  gateway         = "172.21.12.1"
  dns_suffix_list = ["hashicorp.local"]


  template = data.hcp_packer_image.this.cloud_image_id
  tags = {
    "application" = "postgres"
  }
}

# --- Create Boundary targets for the postgres nodes
module "boundary_target" {
  source  = "app.terraform.io/tfo-apj-demos/target/boundary"
  version = "~> 0.0"

  hosts = [
    { 
      "hostname" = module.postgres.virtual_machine_name,
      "address" = module.postgres.ip_address
    }
  ]
  services = [
    { 
      name = "postgres",
      type = "tcp",
      port = "5432"
    }
  ]
  project_name = "grantorchard"
  host_catalog_id = "hcst_7B2FWBRqb0"
  hostname_prefix = "postgres_sbd"
  injected_credential_library_ids = ["clvsclt_bDETPnhh75"]
}

# --- Add to DNS
module "dns" {
  source  = "app.terraform.io/tfo-apj-demos/domain-name-system-management/dns"
  version = "~> 1.0"

  a_records = [
    {
      name      = module.postgres.virtual_machine_name
      addresses = [
        module.postgres.ip_address
      ]
    }
  ]
}

module "database_secrets" {
  source = "github.com/tfo-apj-demos/terraform-vault-postgres-connection.git"

  vault_mount_postgres_path = "postgres"
  database_connection_name = "${var.TFC_WORKSPACE_ID}-postgres"

  database_addresses = [ module.postgres.ip_address ]
  database_username = "postgres"
  database_name = "postgres"
  database_roles = [
    {
      name = "${var.TFC_WORKSPACE_ID}-superuser"
      creation_statements = [
        "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SUPERUSER TO \"{{name}}\"; GRANT ALL PRIVILEGES ON DATABASE postgres TO \"{{name}}\";"
      ]
    }
  ]
}