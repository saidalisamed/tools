# SNS Fast Publish lambda function
# This function uses S3 put events to pick the dropped file and publish SNS notification to the listed
# mobile device endpoints in the file.
#
# Usage:
# ------
# 1. Deploy this function with timeout setting of 5 minutes. Make sure the lambda Role has
#    S3 read/write permissions to the bucket and SNS publish permission.
# 2. Create a S3 bucket and set up events for 'put' to trigger this lambda function.
# 3. In the S3 events configuration, set the event suffix to '.gz'.
# 4. Create a payloads file i.e 'endpoint_list_14032016.json' with contents in the below json format.
# {
#  "Endpoints": [
#    {
#      "EndpointArn": "arn:aws:sns:us-west-2:1111122222:endpoint/GCM/MyApp/55a1ffbf-aefc-3e7a-bd84-3af5bca4fc63",
#      "Message": "{\\\"data\\\": { \\\"message\\\": \\\"Test from Lambda.\\\", \\\"title\\\": \\\"Test\\\"}}"
#    }
#  ]
# }
# 5. If sending the same message to all endpoints, use the following json format.
# {
#  "SameMessage": true,
#  "Message": "{\\\"data\\\": { \\\"message\\\": \\\"Same message to all endpoints.\\\", \\\"title\\\": \\\"Test\\\"}}",
#  "Endpoints": [
#    {
#      "EndpointArn": "arn:aws:sns:us-west-2:1111122222:endpoint/GCM/MyApp/55a1ffbf-aefc-3e7a-bd84-3af5bca4fc63"
#    }
#  ]
# }
# 6. Compress the file using gzip. e.g 'gzip -kf endpoint_list_14032016.json' creates 'endpoint_list_14032016.json.gz'
# 7. Upload the file 'endpoint_list_14032016.json.gz' to the S3 bucket which will trigger this lambda function.
# 8. This function will publish to all endpoints in the json file and log failures in <FILENAME>_error.log.
#
# Tip: Publish even faster by distributing endpoints across multiple smaller json files when the number
# of endpoints exceed over a few 100,000s or increase max_threads variable value to something higher.
#
# License Information
# -------------------
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
#
# Version 1.2
# -----------
# Time logging to s3. Creates a file with time information for each uploaded file
# Get total publish time by calculating difference between earliest and the latest logged time across all files


from __future__ import print_function

import json
import urllib
import zlib

from time import strftime, gmtime
import time

import boto3
import botocore
import concurrent.futures

__original_idea__ = 'Dennis Hills'
__idea_contribution__ = 'Howard Kang'
__author__ = 'Said Ali Samed'
__date__ = '14/03/2016'
__version__ = '1.2'
__updated__ = '02/06/2016'

# ** Configurable settings **
region = 'us-east-1'
max_threads = 1000
log_time = True

# Initialize clients
s3 = boto3.client('s3', region_name=region)
sns = boto3.client('sns', region_name=region)
publish_errors = []
start_time = 0
end_time = 0
bucket = ''
key = ''


def current_time():
    return strftime("%Y-%m-%d %H:%M:%S UTC", gmtime())


def save_to_s3(data, s3_bucket, s3_key):
    try:
        response = s3.put_object(Bucket=s3_bucket, Key=s3_key, Body=data)
        if 'ResponseMetadata' in response.keys() and response['ResponseMetadata']['HTTPStatusCode'] == 200:
            print('Saved file in s3://%s/%s' % (s3_bucket, s3_key))
    except Exception as e:
        print(e)
        raise e


# Logs unix timestamps in s3 in format start_time, end_time, total_time
def log(command):
    global start_time, end_time, bucket, key
    if log_time:
        if command == 'start':
            start_time = time.time()
        elif command == 'end':
            end_time = time.time()
        elif command == 'save':
            data = '%f, %f, %f' % (start_time, end_time, end_time-start_time)
            save_to_s3(data, bucket, key + '_time.log')


def publish(endpoint, message=None):
    global publish_errors
    target_arn = endpoint['EndpointArn'] if 'EndpointArn' in endpoint.keys() else ''
    notification_message = message if message else endpoint['Message'] if 'Message' in endpoint.keys() else ''

    # Get the platform type from the endpoint ARN
    platform = target_arn.split(':')[5].split('/')[1] if len(target_arn) > 0 else ''
    # Format platform specific payload
    platform_message = '{"%s": "%s"}' % (platform, notification_message)

    try:
        response = sns.publish(
            TargetArn=target_arn,
            Message=platform_message,
            MessageStructure='json'
        )
        if not isinstance(response, dict):  # log failed requests only
            publish_errors.append('%s, %s, %s' % (current_time(), target_arn, response))
    except botocore.exceptions.ClientError as e:
        publish_errors.append('%s, %s, %s, %s' %
                              (current_time(),
                               target_arn,
                               ', '.join("%s=%r" % (k, v) for (k, v) in e.response['ResponseMetadata'].iteritems()),
                               e.message))


def lambda_handler(event, context):
    global publish_errors, bucket, key

    # Start time logging
    log('start')

    try:
        # Read the uploaded object from bucket
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.unquote_plus(event['Records'][0]['s3']['object']['key']).decode('utf8')
        response = s3.get_object(Bucket=bucket, Key=key)
        body = json.loads(zlib.decompress(response['Body'].read(), 16+zlib.MAX_WBITS))

        # Check if sending same message to all endpoints
        if "SameMessage" in body.keys() and body['SameMessage']:
            message = body['Message']
        else:
            message = None

        endpoints = body['Endpoints']

        # Publish in parallel using several threads
        e = concurrent.futures.ThreadPoolExecutor(max_workers=max_threads)
        for endpoint in endpoints:
            e.submit(publish, endpoint, message)
        e.shutdown()
    except Exception as e:
        print(e.message + ' Aborting...')
        raise e

    print('Publish complete.')

    # Finish time logging
    log('end')

    # Remove the uploaded object
    try:
        response = s3.delete_object(Bucket=bucket, Key=key)
        if 'ResponseMetadata' in response.keys() and response['ResponseMetadata']['HTTPStatusCode'] == 204:
            print('Removed s3://%s/%s' % (bucket, key))
    except Exception as e:
        print(e)

    # Upload errors if any to S3
    if len(publish_errors) > 0:
        result_data = '\n'.join(publish_errors)
        logfile_key = key.replace('.json.gz', '') + '_error.log'
        save_to_s3(result_data, bucket, logfile_key)

        # Reset publish error log
        publish_errors = []

    # Store time log to s3
    log('save')

if __name__ == "__main__":
    json_content = json.loads(open('event.json', 'r').read())
    lambda_handler(json_content, None)
