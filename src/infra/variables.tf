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

# --- Trigger (Lambda) related variables ---

variable "redshift_jdbc_driver_s3_path" {
  description = <<-EOT
    S3 path to the Redshift JDBC driver jar, used by the Lambda-triggered
    spark-submit step (e.g. s3://<bucket>/jars/redshift-jdbc42-2.1.0.30.jar).
    The driver is proprietary and not committed to this repo - download it
    from https://docs.aws.amazon.com/redshift/latest/mgmt/jdbc20-download-driver.html
    and upload it to this path manually before the first run (see
    src/spark/README.md).
  EOT
  type        = string
}
