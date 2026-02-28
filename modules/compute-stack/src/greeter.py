import json
import os
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns', region_name='us-east-1') # SNS topic is specifically in us-east-1

def lambda_handler(event, context):
    region = os.environ['AWS_REGION']
    email = os.environ['CANDIDATE_EMAIL']
    repo = os.environ['GITHUB_REPO']
    table_name = os.environ['TABLE_NAME']
    topic_arn = os.environ['SNS_TOPIC_ARN']

    # 1. Write to DynamoDB
    table = dynamodb.Table(table_name)
    table.put_item(
        Item={
            'id': str(uuid.uuid4()),
            'timestamp': str(datetime.now()),
            'region': region
        }
    )

    # 2. Publish to SNS
    payload = {
        "email": email,
        "source": "Lambda",
        "region": region,
        "repo": repo
    }
    
    sns.publish(
        TopicArn=topic_arn,
        Message=json.dumps(payload)
    )

    # 3. Return 200 OK with region name
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Success', 'region': region})
    }