# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "cost-optimization-ebs-snapshot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy to allow Lambda to interact with EC2 snapshots and instances
resource "aws_iam_policy" "lambda_ebs_policy" {
  name        = "cost-optimization-ebs"
  description = "Policy to allow Lambda to manage EBS snapshots"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeSnapshots",
          "ec2:DescribeInstances",
          "ec2:DeleteSnapshot"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the Lambda IAM role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_ebs_policy.arn
}