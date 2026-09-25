# Root-level input variables for src/infra

variable "project_name" {
  description = "Short name used to prefix/tag all resources for this project"
  type        = string
}

variable "aws_region" {
  description = "AWS region to provision resources in"
  type        = string
}

# --- Redshift (database) related variables ---

variable "redshift_database_name" {
  description = "Name of the default database created on the Redshift cluster"
  type        = string
}

variable "redshift_master_username" {
  description = "Master username for the Redshift cluster"
  type        = string
}

variable "redshift_master_password" {
  description = "Master user password for the Redshift cluster"
  type        = string
  sensitive   = true
}

variable "redshift_node_type" {
  description = "Instance/node type for the Redshift cluster (kept small for demo purposes)"
  type        = string
}
