from flask import Flask, jsonify, request
import os
import boto3
import uuid

app = Flask(__name__)

# Configuration – read from environment (in CI/CD they are injected)
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE', 'DemoItems')
DYNAMODB_ENDPOINT = os.getenv('DYNAMODB_ENDPOINT')  # optional for localstack

if DYNAMODB_ENDPOINT:
    dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION, endpoint_url=DYNAMODB_ENDPOINT)
else:
    dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)

table = dynamodb.Table(DYNAMODB_TABLE)

@app.route('/items', methods=['GET'])
def list_items():
    response = table.scan()
    items = response.get('Items', [])
    return jsonify(items)

@app.route('/items', methods=['POST'])
def create_item():
    data = request.get_json() or {}
    item_id = str(uuid.uuid4())
    item = {'id': item_id, **data}
    table.put_item(Item=item)
    return jsonify(item), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
