import boto3

cloudwatch = boto3.client('cloudwatch')
rds = boto3.client('rds')

def lambda_handler(event, context):
    response = rds.describe_pending_maintenance_actions()
    os_upgrade_count = 0
    db_upgrade_count = 0
    
    for record in response.get('PendingMaintenanceActions', []):
        db_instance_id = record['ResourceIdentifier'].split(':')[-1]  # Extract DB identifier
        for action in record['PendingMaintenanceActionDetails']:
            action_type = action['Action']
            
            if action_type == 'os-upgrade':
                os_upgrade_count += 1
                cloudwatch.put_metric_data(
                    Namespace='RDSCustomEvents',
                    MetricData=[
                        {
                            'MetricName': 'OSUpgradeAvailable',
                            'Dimensions': [
                                {'Name': 'DBInstanceIdentifier', 'Value': db_instance_id}
                            ],
                            'Value': 1,
                            'Unit': 'Count'
                        }
                    ]
                )
            
            if action_type == 'db-upgrade':
                db_upgrade_count += 1
                cloudwatch.put_metric_data(
                    Namespace='RDSCustomEvents',
                    MetricData=[
                        {
                            'MetricName': 'DBUpgradeAvailable',
                            'Dimensions': [
                                {'Name': 'DBInstanceIdentifier', 'Value': db_instance_id}
                            ],
                            'Value': 1,
                            'Unit': 'Count'
                        }
                    ]
                )
    
    print(f"Detected {os_upgrade_count} OS upgrades available.")
    print(f"Detected {db_upgrade_count} DB upgrades available.")
