# IAM for the Spark (EMR) module
#
# Purpose: IAM roles for the EMR cluster/EC2 instances to read raw data
# from and write curated data to the S3 data lake. Uses AWS managed
# policies for the base EMR permissions to keep this first iteration
# minimal, plus the shared data lake access policy from the s3 module.

variable "data_lake_access_policy_arn" {
  description = "ARN of the S3 data lake access policy (from the s3 module) to attach to the EMR EC2 role"
  type        = string
}

# Role EMR itself assumes to manage the cluster (start/stop instances, etc.)
resource "aws_iam_role" "emr_service_role" {
  name = "${var.project_name}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "emr_service_role" {
  role       = aws_iam_role.emr_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

# Role the EC2 instances (nodes) in the cluster use to run the PySpark jobs
resource "aws_iam_role" "emr_ec2_role" {
  name = "${var.project_name}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attaches the AWS-managed EMR-for-EC2 policy to the node role above, so
# the cluster's EC2 instances (master/core nodes) get the base permissions
# EMR needs to run (e.g., talking to CloudWatch, S3 for logs/data, etc.).
resource "aws_iam_role_policy_attachment" "emr_ec2_role" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Grants the EC2 nodes access to the data lake bucket (raw + curated zones)
resource "aws_iam_role_policy_attachment" "emr_ec2_data_lake_access" {
  role       = aws_iam_role.emr_ec2_role.name
  policy_arn = var.data_lake_access_policy_arn
}

resource "aws_iam_instance_profile" "emr_ec2_profile" {
  name = "${var.project_name}-emr-ec2-profile"
  role = aws_iam_role.emr_ec2_role.name
}
