import boto3
import datetime
import base64
import hashlib


def is_collision(id, table, ddb_client):
    result = ddb_client.get_item(
        Key={'id': {'S': id}},
        TableName=table
    )
    if "Item" in result:
        return True
    return False


def handler(event, context):
    ddb = boto3.client("dynamodb")

    url = event['Key']['url']['S']
    created = str(datetime.datetime.now())
    hash = hashlib.sha256((created+url).encode("ascii")
                          ).hexdigest().encode("ascii")
    id = base64.b32encode(hash).rstrip(b"=")[-8:].lower().decode("ascii")

    # Check for collision and shorten ids over time... could be a long time, though :/
    while is_collision(id, event['TableName'], ddb):
        id = id[:-1]

    table_item = {
        'created': {'S': created},
        'id': {'S': id},
        'url': {'S': url}
    }
    table_item['userid'] = {'S': event.get("userid", "noname")}

    try:
        ddb.put_item(
            TableName=event['TableName'],
            Item=table_item
        )
    except Exception as e:
        return {'status': 500, 'message': str(e)}

    return table_item


if __name__ == "__main__":
    handler({'id': "abcdd123"}, None)
