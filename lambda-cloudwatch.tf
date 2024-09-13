# Lambda function definition
resource "aws_lambda_function" "ebs_snapshot_cleanup" {
  function_name = "cost-optimization-ebs-snapshot"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"

  # Path to lambda Python code
  filename      = "lambda_function.zip"

  # Ensure that you zip your Python code locally
  source_code_hash = filebase64sha256("lambda_function.zip")

  # Lambda function environment variables if needed
  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }
  
  timeout = 10

  # Ensure that the IAM role and policy are created before the Lambda function
  depends_on = [
    aws_iam_role.lambda_execution_role,
    aws_iam_policy.lambda_ebs_policy,
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
}

# CloudWatch EventBridge Rule to trigger Lambda every 2 months
resource "aws_cloudwatch_event_rule" "schedule_rule" {
  name        = "cost-optimization-snapshot-schedule"
  description = "Trigger Lambda every 2 months"
  schedule_expression = "cron(0 0 1 1/2 ? *)"  # Cron job to trigger Lambda very 2 months

  # Ensure that the Lambda function is created before the EventBridge rule
  depends_on = [
    aws_lambda_function.ebs_snapshot_cleanup
  ]
}

# Lambda permission to be invoked by EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ebs_snapshot_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_rule.arn
}

# CloudWatch Event Target to trigger Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule_rule.name
  target_id = "ebsSnapshotCleanup"
  arn       = aws_lambda_function.ebs_snapshot_cleanup.arn
}