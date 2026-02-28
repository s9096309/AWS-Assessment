import json
import os
import boto3
import traceback

ecs = boto3.client('ecs')

def lambda_handler(event, context):
    region = os.environ.get('AWS_REGION', 'UNKNOWN')
    
    try:
        cluster_name = os.environ['CLUSTER_NAME']
        task_definition = os.environ['TASK_DEFINITION']
        subnet_id = os.environ['SUBNET_ID']
        security_group_id = os.environ['SECURITY_GROUP_ID']

        # Trigger the Fargate task
        response = ecs.run_task(
            cluster=cluster_name,
            taskDefinition=task_definition,
            launchType='FARGATE',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': [subnet_id],
                    'securityGroups': [security_group_id],
                    'assignPublicIp': 'ENABLED' 
                }
            }
        )
        
        # ECS run_task can succeed but still fail to launch a task (e.g., lack of capacity)
        if response.get('failures'):
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'message': 'ECS API succeeded, but task failed to launch.',
                    'region': region,
                    'failures': response['failures']
                })
            }

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Fargate task dispatched successfully',
                'region': region,
                'taskArn': response['tasks'][0]['taskArn'] if response.get('tasks') else 'Failed'
            })
        }
        
    except Exception as e:
        # Catch any AWS API errors (like IAM propagation issues) and return them nicely
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'An error occurred while dispatching the task',
                'region': region,
                'error': str(e),
                'trace': traceback.format_exc()
            })
        }