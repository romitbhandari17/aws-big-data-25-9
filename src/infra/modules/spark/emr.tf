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
    instance_profile = aws_iam_instance_profile.emr_ec2_profile.arn
  }

  tags = {
    Project = var.project_name
  }
}

output "cluster_id" {
  description = "ID of the EMR cluster"
  value       = aws_emr_cluster.spark.id
}
