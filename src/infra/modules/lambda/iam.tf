# IAM for the Lambda module
#
# Purpose: execution role for the EMR-step-trigger Lambda - basic logging
# plus permission to add steps to (and describe) the specific EMR cluster.

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-trigger-emr-step-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "emr_add_steps" {
  statement {
    sid    = "SubmitEmrSteps"
    effect = "Allow"
    actions = [
      "elasticmapreduce:AddJobFlowSteps",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:DescribeStep",
    ]
    resources = ["*"] # EMR step actions don't support resource-level restriction to a single cluster ARN
  }
}

resource "aws_iam_role_policy" "emr_add_steps" {
  name   = "${var.project_name}-lambda-emr-add-steps"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.emr_add_steps.json
}
