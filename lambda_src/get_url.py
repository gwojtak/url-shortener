import boto3


def handler(event, context):
    ddb = boto3.client("dynamodb")

    result = ddb.get_item(
        TableName=event['TableName'],
        Key=event['Key']
    )
    if "Item" not in result:
        return {'status': 404, 'message': "Not Found"}
    else:
        # Send Telemetry to Timestream or something
        return result['Item']


if __name__ == "__main__":
    handler({'id': "abcdd123"}, None)
