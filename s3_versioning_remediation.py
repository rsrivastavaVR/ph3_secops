import boto3
import json

def lambda_handler(event, context):
    s3_client = boto3.client('s3')
    bucket_name = event['BucketName']
    
    response = s3_client.put_bucket_versioning(
        Bucket=bucket_name,
        VersioningConfiguration={
            'Status': 'Enabled',
        },
    )
