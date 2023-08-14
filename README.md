# SecOps Code Implementation

The Terraform stack here creates a custom Detective Control and a custom Reactive Control using AWS Config and AWS Lambda. 

The Detective Control checks if bucket versioning is enabled on S3 buckets, and this check is triggered by any change/addition/deletion in S3 resources. The auto-remediation function (Reactive Control) enables versioning for buckets that don't have it. 

Detected changes in S3 buckets would trigger a Config rule, that in turn invokes a Lambda function which checks for versioning on each bucket. Similarly, an SSM document gets triggered if a non-compliant resource exists, which invokes a second Lambda function that enables versioning for that bucket. 
