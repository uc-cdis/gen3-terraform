import os
import boto3
from datetime import datetime

ec2 = boto3.client('ec2')
ssm = boto3.client('ssm')

def handler(event, context):
    images = ec2.describe_images(
        Owners=[os.environ['SOURCE_AMI_ACCOUNT']],
        Filters=[{'Name':'name','Values':[os.environ['AMI_NAME_PATTERN']]}]
    )['Images']
    images.sort(key=lambda i: i['CreationDate'], reverse=True)
    latest_ami = images[0]['ImageId']

    param_name = f"/gen3/squid-ami-{os.environ['ENV_VPC_NAME']}"
    ssm.put_parameter(
        Name      = param_name,
        Value     = latest_ami,
        Type      = 'String',
        Overwrite = True
    )

    return {
        'statusCode': 200,
        'body': f"Updated {param_name} → {latest_ami} at {datetime.utcnow().isoformat()}"
    }
