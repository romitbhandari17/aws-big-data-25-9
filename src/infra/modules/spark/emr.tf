# Spark module (Phase 1 - AWS EMR running PySpark)
#
# First iteration: a minimal EMR cluster (single core node, no separate
# task nodes) that runs the PySpark jobs in src/spark against the S3
# data lake (raw -> curated) (see docs/PROJECT_CONTEXT.md, section 6.1).

variable "project_name" {
  description = "Project name, used to build resource names/identifiers"
  type        = string
}

variable "log_bucket_name" {
  description = "S3 bucket name (data lake bucket) used to store EMR step/cluster logs"
  type        = string
}

variable "subnet_id" {
  description = "VPC subnet the EMR cluster's instances launch into (needs to be in the same VPC Redshift uses, so the two can reach each other on 5439)"
  type        = string
}

# Extra security group attached to every EMR node (in addition to EMR's own
# auto-managed ones), purely so Redshift has a stable SG id to allow
# inbound JDBC traffic from (see modules/redshift/redshift.tf).
resource "aws_security_group" "emr_client" {
  name        = "${var.project_name}-emr-client"
  description = "Attached to EMR nodes, referenced by Redshifts SG to allow inbound JDBC from Spark"
  vpc_id      = data.aws_subnet.emr.vpc_id

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

data "aws_subnet" "emr" {
  id = var.subnet_id
}

resource "aws_emr_cluster" "spark" {
  name          = "${var.project_name}-spark"
  release_label = "emr-7.1.0"
  applications  = ["Spark"]

  log_uri = "s3://${var.log_bucket_name}/emr-logs/"

  # Single small core instance group - enough to demo PySpark jobs, not
  # sized for real production data volumes.
  master_instance_group {
    instance_type = "m5.xlarge"
  }

  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 1
  }

  service_role = aws_iam_role.emr_service_role.arn
  ec2_attributes {
    instance_profile                  = aws_iam_instance_profile.emr_ec2_profile.arn
    subnet_id                         = var.subnet_id
    additional_master_security_groups = aws_security_group.emr_client.id
    additional_slave_security_groups  = aws_security_group.emr_client.id
  }

  tags = {
    Project = var.project_name
  }
}

output "cluster_id" {
  description = "ID of the EMR cluster"
  value       = aws_emr_cluster.spark.id
}

output "client_security_group_id" {
  description = "ID of the security group attached to EMR nodes (used to allow inbound JDBC on the Redshift SG)"
  value       = aws_security_group.emr_client.id
}
