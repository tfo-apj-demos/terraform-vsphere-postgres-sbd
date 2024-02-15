# output "workspace_environment_variables" {
#   value = null_resource.this
# }

output "role_paths" {
  value = module.database_secrets.role_paths
}