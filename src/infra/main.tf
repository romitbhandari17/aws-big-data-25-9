# Root module - wires together the S3, Redshift, and Spark (EMR) modules
# for Phase 1 (see docs/PROJECT_CONTEXT.md).

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
}

module "spark" {
  source = "./modules/spark"

  project_name                = var.project_name
  log_bucket_name             = module.s3.bucket_name
  data_lake_access_policy_arn = module.s3.data_lake_access_policy_arn
}
