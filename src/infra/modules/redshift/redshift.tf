# Redshift module (Phase 1 - analytical queries)
#
# First iteration: a single-node Redshift cluster (kept small for demo
# purposes) that will later load curated data from the S3 data lake
# (see docs/PROJECT_CONTEXT.md, section 6).

variable "project_name" {
  description = "Project name, used to build resource names/identifiers"
  type        = string
}

variable "database_name" {
  description = "Name of the default database created on the cluster"
  type        = string
}

variable "master_username" {
  description = "Master username for the cluster"
  type        = string
}

variable "master_password" {
  description = "Master user password for the cluster"
  type        = string
  sensitive   = true
}

variable "node_type" {
  description = "Instance/node type for the cluster"
  type        = string
}

resource "aws_redshift_cluster" "analytics" {
  cluster_identifier = "${var.project_name}-redshift"
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = var.master_password
  node_type          = var.node_type
  cluster_type       = "single-node" # single node for demo/dev - not production sizing

  # Allows this cluster to read curated data from S3 (role attached below,
  # in iam.tf).
  iam_roles = [aws_iam_role.redshift_s3_access.arn]

  skip_final_snapshot = true # simplifies teardown for a demo environment

  tags = {
    Project = var.project_name
  }
}

output "cluster_endpoint" {
  description = "Endpoint of the Redshift cluster"
  value       = aws_redshift_cluster.analytics.endpoint
}
