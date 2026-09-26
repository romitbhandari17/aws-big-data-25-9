# Lambda module (Phase 1 - event-driven orchestration)
#
# Purpose: submits the PySpark orders ETL job as an EMR step whenever a
# new file lands under the S3 raw zone's orders/ prefix, so the pipeline
# (S3 -> EMR/PySpark -> Redshift) runs automatically instead of requiring
# a manual `aws emr add-steps` (see docs/PROJECT_CONTEXT.md, section 6).

variable "project_name" {
  description = "Project name, used to build resource names/identifiers"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 data lake bucket to watch for new raw orders files"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 data lake bucket"
  type        = string
}

variable "emr_cluster_id" {
  description = "ID of the EMR cluster to submit the spark-submit step to"
  type        = string
}

variable "spark_script_s3_path" {
  description = "S3 path to the process_orders.py script (uploaded by the s3 module)"
  type        = string
}

variable "redshift_jdbc_driver_s3_path" {
  description = "S3 path to the Redshift JDBC driver jar (must be uploaded manually - see src/spark/README.md)"
  type        = string
}

variable "redshift_jdbc_url" {
  description = "Redshift JDBC connection string, e.g. jdbc:redshift://<endpoint>:5439/<db>"
  type        = string
}

variable "redshift_user" {
  description = "Redshift master username"
  type        = string
}

variable "redshift_password" {
  description = "Redshift master password"
  type        = string
  sensitive   = true
}

variable "redshift_table" {
  description = "Redshift table the aggregated summary is loaded into"
  type        = string
  default     = "orders_summary"
}

# Packages the Lambda handler source into the zip archive Lambda expects.
data "archive_file" "trigger_emr_step" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda/emr.py"
  output_path = "${path.module}/build/emr.zip"
}

resource "aws_lambda_function" "trigger_emr_step" {
  function_name    = "${var.project_name}-trigger-emr-step"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "emr.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.trigger_emr_step.output_path
  source_code_hash = data.archive_file.trigger_emr_step.output_base64sha256

  environment {
    variables = {
      EMR_CLUSTER_ID               = var.emr_cluster_id
      DATA_LAKE_BUCKET             = var.bucket_name
      SPARK_SCRIPT_S3_PATH         = var.spark_script_s3_path
      REDSHIFT_JDBC_DRIVER_S3_PATH = var.redshift_jdbc_driver_s3_path
      REDSHIFT_JDBC_URL            = var.redshift_jdbc_url
      REDSHIFT_USER                = var.redshift_user
      REDSHIFT_PASSWORD            = var.redshift_password
      REDSHIFT_TABLE               = var.redshift_table
    }
  }

  tags = {
    Project = var.project_name
  }
}

# Lets S3 invoke this function (scoped to this bucket only).
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_emr_step.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.bucket_arn
}

# Fires the Lambda on every new object under raw/orders/ (new orders batch).
resource "aws_s3_bucket_notification" "raw_orders" {
  bucket = var.bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_emr_step.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/orders/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
