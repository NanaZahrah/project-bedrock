import json
import urllib.parse

def lambda_handler(event, context):
    try:
        bucket = event['Records'][0]['s3']['bucket']['name']
        filename = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
        print(f"Image received: {filename}")
        return {
            'statusCode': 200,
            'body': json.dumps(f"Successfully processed image: {filename}")
        }
    except Exception as e:
        print(e)
        raise e