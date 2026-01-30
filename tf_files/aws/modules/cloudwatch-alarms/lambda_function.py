import json
import urllib.request
import boto3

secrets = boto3.client("secretsmanager")

def get_slack_webhook_url() -> str:
    secret_id = os.environ["SLACK_WEBHOOK_SECRET_NAME"]
    resp = secrets.get_secret_value(SecretId=secret_id)
    url = resp.get("SecretString")
    if not url:
        raise RuntimeError("SecretString is empty")
    return url.strip()

SLACK_WEBHOOK_URL = get_slack_webhook_url()

VPC_NAME = os.environ["VPC_NAME"]

PRESET_MESSAGE = (
    f":warning: :alert: *AWS Alert Notification* :alert:\n"
    f"{VPC_NAME} Elasticsearch Cluster is Red! "
    "Indices may need to be cleaned out. "
    "Trigger ES garbage collection job to cleanup indices.\n"
)

def lambda_handler(event, context):
    payload = json.dumps({"text": PRESET_MESSAGE}).encode("utf-8")

    req = urllib.request.Request(
        SLACK_WEBHOOK_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(req) as resp:
        return {
            "statusCode": resp.status,
            "body": resp.read().decode(),
        }
