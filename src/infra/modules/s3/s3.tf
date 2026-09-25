# S3 module (Phase 1 - S3 Data Lake)
#
# First iteration: a single bucket for the data lake, with raw/ and
# curated/ prefixes (folders) for orders, customers, and products data
# (see docs/PROJECT_CONTEXT.md, sections 3 and 5).

variable "project_name" {
  description = "Project name, used to build the bucket name"
  type        = string
}

# The data lake bucket itself
resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project_name}-data-lake"

  tags = {
    Project = var.project_name
  }
}

# "Folders" for the raw and curated zones (S3 has no real folders - these
# are zero-byte objects with a trailing slash key, just to make the zones
# visible/browsable in the console for the demo).
resource "aws_s3_object" "raw_zone" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/"
}

resource "aws_s3_object" "curated_zone" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "curated/"
}

output "bucket_name" {
  description = "Name of the S3 data lake bucket"
  value       = aws_s3_bucket.data_lake.id
}
