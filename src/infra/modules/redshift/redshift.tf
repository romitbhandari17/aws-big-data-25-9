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

variable "subnet_ids" {
  description = "VPC subnet IDs for the Redshift cluster subnet group"
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group ID (EMR client SG) allowed inbound JDBC access on port 5439"
  type        = string
}

data "aws_subnet" "first" {
  id = var.subnet_ids[0]
}

resource "aws_redshift_subnet_group" "analytics" {
  name       = "${var.project_name}-redshift-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Project = var.project_name
  }
}

# Allows inbound JDBC (5439) only from the EMR cluster's security group -
# nothing else can reach Redshift on this port (see docs/PROJECT_CONTEXT.md,
# section 6, and the "Networking" gap it called out).
resource "aws_security_group" "redshift" {
  name        = "${var.project_name}-redshift-sg"
  description = "Allows inbound JDBC (5439) from the EMR/Spark cluster only"
  vpc_id      = data.aws_subnet.first.vpc_id

  ingress {
    from_port       = 5439
    to_port         = 5439
    protocol        = "tcp"
    security_groups = [var.allowed_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_redshift_cluster" "analytics" {
  cluster_identifier = "${var.project_name}-redshift"
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = var.master_password
  node_type          = var.node_type
  cluster_type       = "single-node" # single node for demo/dev - not production sizing

  cluster_subnet_group_name = aws_redshift_subnet_group.analytics.name
  vpc_security_group_ids    = [aws_security_group.redshift.id]

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

output "jdbc_url" {
  description = "JDBC connection string for Spark's Redshift writer"
  value       = "jdbc:redshift://${aws_redshift_cluster.analytics.endpoint}/${var.database_name}"
}
