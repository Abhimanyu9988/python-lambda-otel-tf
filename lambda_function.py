import boto3
import json
from custom_encoder import CustomEncoder
import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


dynamodbTableName = 'student-abhi-python'
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(dynamodbTableName)


getMethod = 'GET'
postMethod = 'POST'
patchMethod = 'PATCH'
deleteMethod = 'DELETE'
healthPath = '/health'
studentPath = '/student'
studentsPath = '/students'



def lambda_handler(event, contest):
    logger.info(event)
    httpMethod = event['httpMethod']
    path = event['path']
    if httpMethod == getMethod and path == healthPath:
        response = buildResponse(200)
    elif httpMethod == getMethod and path == studentPath:
        response = getStudent(event['queryStringParameters']['studentId'])
    elif httpMethod == getMethod and path == studentsPath:
        response = getStudents()
    elif httpMethod == postMethod and path == studentPath:
        response = saveStudent(json.loads(event['body']))
    elif httpMethod == patchMethod and path == studentPath:
        requestBody = json.loads(event['body'])
        response = modifyStudent(requestBody['studentId'], requestBody['updateKey'], requestBody['updateValue'])
    elif httpMethod == deleteMethod and path == studentPath:
        requestBody = json.loads(event['body'])
        response = deleteStudent(requestBody['studentId'])
    else:
        response = buildResponse(404, 'Not Found')

    return response


def getStudent(studentId):
    try:
        response = table.get_item(
            Key={
                'studentId': studentId
            }
        )
        if 'Item' in response:
            return buildResponse(200, response['Item'])
        else:
            return buildResponse(404, {'Message': 'StudentId: %s not found' % studentId})
    except:
        logger.exception('Log it here for now')

def getStudents():
    try:
        response = table.scan()
        result = response['Items']

        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            result.extend(response['Items'])

        body = {
            'students': result
        }
        return buildResponse(200, body)
    except:
        logger.exception('Log it here for now')


def saveStudent(requestBody):
    try:
        table.put_item(Item=requestBody)
        body = {
            'Operation': 'SAVE',
            'Message': 'SUCCESS',
            'Item': requestBody
        }
        return buildResponse(200, body)
    except:
        logger.exception('Log it here for now')

def modifyStudent(studentId, updateKey, updateValue):
    try:
        response = table.update_item(
            Key = {
                'studentId': studentId
            },
            UpdateExpression='set %s = :value' % updateKey,
            ExpressionAttributeValues={
                ':value': updateValue
            },
            ReturnValues='UPDATED_NEW'
        )
        body = {
            'Operation': 'UPDATE',
            'Message': 'SUCCESS',
            'UpdatedAttribute': response
        }
        return buildResponse(200, body)
    except:
        logger.exception('Log it here for now')

def deleteStudent(studentId):
    try:
        response = table.delete_item(
            Key = {
                'studentId': studentId
            },
            ReturnValues='ALL_OLD'
        )
        body = {
            'Operation': 'DELETE',
            'Message': 'SUCCESS',
            'deletedItem': response
        }
        return buildResponse(200, body)
    except:
        logger.exception('Log it here for now')

def buildResponse(statusCode, body=None):
    response = {
        'statusCode': statusCode,
        'headers': {
            'ContentType': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    }
    if body is not None:
        response['body'] = json.dumps(body, cls=CustomEncoder)
    return response
