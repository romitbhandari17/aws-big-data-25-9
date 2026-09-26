# Root module - wires together the S3, Redshift, Spark (EMR), and Lambda
# (event-trigger) modules for Phase 1 (see docs/PROJECT_CONTEXT.md).

# Default VPC/subnets - EMR and Redshift both need to land in the same
# VPC so Redshift's security group can allow inbound JDBC from EMR's
# (see modules/spark/emr.tf and modules/redshift/redshift.tf). Using the
# account's default VPC keeps this demo simple (no custom networking).
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "s3" {
  source       = "./modules/s3"
  project_name = var.project_name
}

module "redshift" {
  source = "./modules/redshift"

  project_name                = var.project_name
  database_name               = var.redshift_database_name
  master_username             = var.redshift_master_username
  master_password             = var.redshift_master_password
  node_type                   = var.redshift_node_type
  data_lake_access_policy_arn = module.s3.data_lake_access_policy_arn
  subnet_ids                  = data.aws_subnets.default.ids
  allowed_security_group_id   = module.spark.client_security_group_id
}

module "spark" {
  source = "./modules/spark"

  project_name                = var.project_name
  log_bucket_name             = module.s3.bucket_name
  data_lake_access_policy_arn = module.s3.data_lake_access_policy_arn
  subnet_id                   = data.aws_subnets.default.ids[0]
}

module "lambda" {
  source = "./modules/lambda"

  project_name                 = var.project_name
  bucket_name                  = module.s3.bucket_name
  bucket_arn                   = module.s3.bucket_arn
  emr_cluster_id               = module.spark.cluster_id
  spark_script_s3_path         = module.s3.spark_script_s3_path
  redshift_jdbc_driver_s3_path = var.redshift_jdbc_driver_s3_path
  redshift_jdbc_url            = module.redshift.jdbc_url
  redshift_user                = var.redshift_master_username
  redshift_password            = var.redshift_master_password
}
