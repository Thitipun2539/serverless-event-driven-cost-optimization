**Serverless Event-Driven Cost Optimization**

A Lambda event-driven function with Python to trigger Cloud Watch’s Event Bridge to fetch EBS snapshots, filter the stale resources and delete them if they are not associated with its volume to eliminate unnecessary stale resources.

This will create a Lambda function with the zipped lambda_function.py on the working directory and attach the IAM role created in the beginning. We also set the CloudWatch event to trigger the Lambda function once every 2 months.

This function will help optimise the cost by deleting the snapshots that are no longer needed and can be improved upon with any other AWS resources.
