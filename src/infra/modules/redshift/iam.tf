# IAM for the Redshift module
#
# Purpose: IAM role attached to the Redshift cluster allowing it to run
# COPY commands from the S3 curated zone.

variable "data_lake_access_policy_arn" {
  description = "ARN of the S3 data lake access policy (from the s3 module) to attach to this role"
  type        = string
}

# Role that Redshift assumes to access other AWS services (S3, in this case)
resource "aws_iam_role" "redshift_s3_access" {
  name = "${var.project_name}-redshift-s3-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "redshift.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_s3_access" {
  role       = aws_iam_role.redshift_s3_access.name
  policy_arn = var.data_lake_access_policy_arn
}
