from __future__ import print_function

from datetime import datetime
from time import strftime, gmtime

import StringIO
import csv
import json
import urllib
import zlib
import boto3
import botocore
import concurrent.futures


__original_idea__ = 'Dilip Sant'
__author__ = 'Said Ali Samed'
__date__ = '24/04/2016'
__version__ = '1.0'

# ** Configurable settings **
region = 'us-east-1'
max_threads = 10

# Initialize clients
s3 = boto3.client('s3', region_name=region)
cw = boto3.client('cloudwatch', region_name=region)
errors = []
csv_fields = ['date', 'time', 'x-edge-location', 'sc-bytes', 'c-ip', 'cs-method', 'cs-host', 'cs-uri-stem',
              'sc-status', 'cs-referer', 'cs-user-agent', 'cs-uri-query', 'cs-cookie', 'x-edge-result-type',
              'x-edge-request-id', 'x-host-header', 'cs-protocol', 'cs-bytes', 'time-taken', 'x-forwarded-for',
              'ssl-protocol', 'ssl-cipher', 'x-edge-response-result-type']


def current_time():
    return strftime("%Y-%m-%d %H:%M:%S UTC", gmtime())


def put_cw_metric_data(data):
    global errors

    try:
        date_string = data['date'] + ' ' + data['time']
        date_object = datetime.strptime(date_string, '%Y-%m-%d %H:%M:%S')

        metric_data = []
        skip_fields = ['x-edge-request-id', 'x-host-header', 'cs-protocol', 'cs-bytes', 'time-taken', 'x-forwarded-for']
        for field in csv_fields:
            if field in skip_fields: continue  # skip unwanted fields
            metric_data.append({
                'MetricName': data[field],
                'Timestamp': date_object,
                'Value': 1
            })

        response = cw.put_metric_data(
            Namespace=data['cs-host'],
            MetricData=metric_data
        )

        if not isinstance(response, dict):  # log failed requests only
            errors.append('%s, %s' % (current_time(), response))
    except botocore.exceptions.ClientError as e:
        errors.append('%s, %s, %s' %
                       (current_time(),
                           ', '.join("%s=%r" % (k, v) for (k, v) in e.response['ResponseMetadata'].iteritems()),
                           e.message))


def lambda_handler(event, context):
    global errors
    try:
        # Read the uploaded csv file from the bucket into python dictionary
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.unquote_plus(event['Records'][0]['s3']['object']['key']).decode('utf8')
        response = s3.get_object(Bucket=bucket, Key=key)
        body = zlib.decompress(response['Body'].read(), 16+zlib.MAX_WBITS)
        body = '\n'.join(body.split('\n')[2:])  # remove first 2 (header) lines
        reader = csv.DictReader(StringIO.StringIO(body),
                                fieldnames=csv_fields,
                                delimiter='\t')

        # Put events in parallel using several threads
        e = concurrent.futures.ThreadPoolExecutor(max_workers=max_threads)
        for line in reader:
            e.submit(put_cw_metric_data, line)
        e.shutdown()
    except Exception as e:
        print(e.message + ' Aborting...')
        raise e

    print('All entries written to Cloudwatch.')

    # Upload errors if any to S3
    if len(errors) > 0:
        try:
            result_data = '\n'.join(errors)
            logfile_key = key.replace('.csv.gz', '') + '_error.log'
            response = s3.put_object(Bucket=bucket, Key=logfile_key, Body=result_data)
            if 'ResponseMetadata' in response.keys() and response['ResponseMetadata']['HTTPStatusCode'] == 200:
                print('Cloudwatch put errors saved in s3://%s/%s' % (bucket, logfile_key))
        except Exception as e:
            print(e)
            raise e
        # Reset Cloudwatch put error log
        errors = []


if __name__ == "__main__":
    json_content = json.loads(open('event.json', 'r').read())
    lambda_handler(json_content, None)
