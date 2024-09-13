**Serverless Event-Driven Cost Optimization**

A Lambda event-driven function with Python to trigger Cloud Watch’s Event Bridge to fetch EBS snapshot, filter the stale resources and delete them if they are not associated with its volume to eliminate unnecessary stale resources.

**Prepare IAM role and policies for Lambda function**

Iam-policy.tf:

\# IAM Role for Lambda

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

\# Policy to allow Lambda to interact with EC2 snapshots and instances

resource "aws_iam_policy" "lambda_ebs_policy" {

name = "cost-optimization-ebs"

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

Effect = "Allow",

Resource = "\*"

}

]

})

}

\# Attach the policy to the Lambda IAM role

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {

role = aws_iam_role.lambda_execution_role.name

policy_arn = aws_iam_policy.lambda_ebs_policy.arn

}

**Create lambda code with Python boto3 module**

lambda_function:

import boto3

def lambda_handler(event, context):

ec2 = boto3.client('ec2')

\# Get all EBS snapshots

response = ec2.describe_snapshots(OwnerIds=['self'])

\# Get all active EC2 instance IDs

instances_response = ec2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])

active_instance_ids = set()

for reservation in instances_response['Reservations']:

for instance in reservation['Instances']:

active_instance_ids.add(instance['InstanceId'])

\# Iterate through each snapshot and delete if it's not attached to any volume or the volume is not attached to a running instance

for snapshot in response['Snapshots']:

snapshot_id = snapshot['SnapshotId']

volume_id = snapshot.get('VolumeId')

if not volume_id:

\# Delete the snapshot if it's not attached to any volume

ec2.delete_snapshot(SnapshotId=snapshot_id)

print(f"Deleted EBS snapshot {snapshot_id} as it was not attached to any volume.")

else:

\# Check if the volume still exists

try:

volume_response = ec2.describe_volumes(VolumeIds=[volume_id])

if not volume_response['Volumes'][0]['Attachments']:

ec2.delete_snapshot(SnapshotId=snapshot_id)

print(f"Deleted EBS snapshot {snapshot_id} as it was taken from a volume not attached to any running instance.")

except ec2.exceptions.ClientError as e:

if e.response['Error']['Code'] == 'InvalidVolume.NotFound':

\# The volume associated with the snapshot is not found (it might have been deleted)

ec2.delete_snapshot(SnapshotId=snapshot_id)

print(f"Deleted EBS snapshot {snapshot_id} as its associated volume was not found.")

Install boto3 locally on the working directory:

pip install boto3 -t .

Zip the code on the working directory so we can refer it in Terraform.

This code will fetch the ebs snapshot and instance’s id, then us if else statement to check whether the snapshot still associated with the ebs volume or not, if not then delete such stale snapshots.

**Prepare AWS Lambda**

lambda-cloudwatch.tf:

\# Lambda function definition

resource "aws_lambda_function" "ebs_snapshot_cleanup" {

function_name = "cost-optimization-ebs-snapshot"

runtime = "python3.10"

role = aws_iam_role.lambda_execution_role.arn

handler = "lambda_function.lambda_handler"

\# Path to lambda Python code

filename = "lambda_function.zip"

\# Ensure that you zip your Python code locally

source_code_hash = filebase64sha256("lambda_function.zip")

\# Lambda function environment variables if needed

environment {

variables = {

LOG_LEVEL = "INFO"

}

}

timeout = 10

\# Ensure that the IAM role and policy are created before the Lambda function

depends_on = [

aws_iam_role.lambda_execution_role,

aws_iam_policy.lambda_ebs_policy,

aws_iam_role_policy_attachment.lambda_policy_attachment

]

}

\# CloudWatch EventBridge Rule to trigger Lambda every 2 months

resource "aws_cloudwatch_event_rule" "schedule_rule" {

name = "cost-optimization-snapshot-schedule"

description = "Trigger Lambda every 2 months"

schedule_expression = "cron(0 0 1 1/2 ? \*)" \# Cron job to trigger Lambda very 2 months

\# Ensure that the Lambda function is created before the EventBridge rule

depends_on = [

aws_lambda_function.ebs_snapshot_cleanup

]

}

\# Lambda permission to be invoked by EventBridge

resource "aws_lambda_permission" "allow_eventbridge" {

statement_id = "AllowExecutionFromEventBridge"

action = "lambda:InvokeFunction"

function_name = aws_lambda_function.ebs_snapshot_cleanup.function_name

principal = "events.amazonaws.com"

source_arn = aws_cloudwatch_event_rule.schedule_rule.arn

}

\# CloudWatch Event Target to trigger Lambda

resource "aws_cloudwatch_event_target" "lambda_target" {

rule = aws_cloudwatch_event_rule.schedule_rule.name

target_id = "ebsSnapshotCleanup"

arn = aws_lambda_function.ebs_snapshot_cleanup.arn

}

This will create a Lambda function with the zipped lambda_function.py on the working directory and attach the IAM role created in the beginning. We also set CloudWatch event to trigger the Lambda function once every 2 months.

This function will help optimized the cost by delete the snapshots that no longer needed and can be improved upon with any other AWS resources.
