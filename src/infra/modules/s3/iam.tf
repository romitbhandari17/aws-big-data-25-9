# IAM for the S3 module
#
# Purpose: a reusable IAM policy granting read/write access to this data
# lake bucket. Other modules (EMR, Redshift) attach this policy to their
# own roles instead of duplicating the S3 permissions.

data "aws_iam_policy_document" "data_lake_access" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.data_lake.arn]
  }

  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.data_lake.arn}/*"]
  }
}

resource "aws_iam_policy" "data_lake_access" {
  name   = "${var.project_name}-data-lake-access"
  policy = data.aws_iam_policy_document.data_lake_access.json
}

output "data_lake_access_policy_arn" {
  description = "ARN of the IAM policy granting access to the data lake bucket"
  value       = aws_iam_policy.data_lake_access.arn
}
