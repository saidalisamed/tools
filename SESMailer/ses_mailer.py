# SES Mailer lambda function
# This function uses S3 put events to pick the dropped file and send emails using SES to the listed
# email addresses in the file.
#
# Usage:
# ------
# 1. Deploy this function with timeout setting of 5 minutes. Make sure the lambda Role has
#    S3 read/write permissions to the bucket and ses:Send* permission.
# 2. Create a S3 bucket and set up events for 'put' to trigger this lambda function.
# 3. In the S3 events configuration, set the event suffix to '.gz'.
# 4. Create a mailing list file i.e 'mailing_list_14032016.csv' with contents in the below json format.
#
#    me@example.com, you@example.com, optional message or leave blank to use the generic template
#
# 5. Create your email template in file email-template.html and upload to S3 bucket.
# 6. Compress the file using gzip. e.g 'gzip -kf mailing_list_14032016.csv' creates 'mailing_list_14032016.csv.gz'
# 7. Upload the file 'mailing_list_14032016.csv.gz' to the S3 bucket which will trigger this lambda function.
# 8. This function will send email to all addresses in the csv file and log failures in <FILENAME>_error.log.
#
# Tip: Send even faster by distributing emails addresses across multiple smaller csv files when the number
# of addresses exceed over a few 100,000s or increase max_threads variable value to something higher.
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

from __future__ import print_function

import StringIO
import csv
import json
import urllib
import zlib

from time import strftime, gmtime

import boto3
import botocore
import concurrent.futures

__author__ = 'Said Ali Samed'
__date__ = '10/04/2016'
__version__ = '1.0'
__updated__ = 'No updates yet'

# ** Configurable settings **
region = 'us-east-1'
max_threads = 10
email_template_file = 'email-template.html'

# Initialize clients
s3 = boto3.client('s3', region_name=region)
ses = boto3.client('ses', region_name=region)
send_errors = []
generic_message = ''


def current_time():
    return strftime("%Y-%m-%d %H:%M:%S UTC", gmtime())


def send_mail(from_address, to_address, message=None):
    global send_errors
    raw_message = message if message and len(message.strip()) > 0 else generic_message
    print('Raw message being sent:\n' + raw_message)

    try:
        response = ses.send_raw_email(
            Source=from_address,
            Destinations=[
                to_address,
            ],
            RawMessage={
                'Data': raw_message
            }
        )
        print(response)
        if not isinstance(response, dict):  # log failed requests only
            send_errors.append('%s, %s, %s' % (current_time(), to_address, response))
    except botocore.exceptions.ClientError as e:
        send_errors.append('%s, %s, %s, %s' %
                           (current_time(),
                               to_address,
                               ', '.join("%s=%r" % (k, v) for (k, v) in e.response['ResponseMetadata'].iteritems()),
                               e.message))


def lambda_handler(event, context):
    global send_errors
    global generic_message
    try:
        # Read the uploaded csv file from the bucket into python dictionary list
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.unquote_plus(event['Records'][0]['s3']['object']['key']).decode('utf8')
        response = s3.get_object(Bucket=bucket, Key=key)
        body = zlib.decompress(response['Body'].read(), 16+zlib.MAX_WBITS)
        print(body)
        reader = csv.DictReader(StringIO.StringIO(body), fieldnames=['from_address', 'to_address', 'message'])

        # Read the email template file
        response = s3.get_object(Bucket=bucket, Key=email_template_file)
        generic_message = response['Body'].read()
        print(generic_message)

        # Send in parallel using several threads
        e = concurrent.futures.ThreadPoolExecutor(max_workers=max_threads)
        for row in reader:
            e.submit(send_mail, row['from_address'], row['to_address'], row['message'])
        e.shutdown()
    except Exception as e:
        print(e.message + ' Aborting...')
        raise e

    print('Send email complete.')

    # Remove the uploaded csv file
    try:
        #response = s3.delete_object(Bucket=bucket, Key=key)
        if 'ResponseMetadata' in response.keys() and response['ResponseMetadata']['HTTPStatusCode'] == 204:
            print('Removed s3://%s/%s' % (bucket, key))
    except Exception as e:
        print(e)

    # Upload errors if any to S3
    if len(send_errors) > 0:
        try:
            result_data = '\n'.join(send_errors)
            logfile_key = key.replace('.csv.gz', '') + '_error.log'
            response = s3.put_object(Bucket=bucket, Key=logfile_key, Body=result_data)
            if 'ResponseMetadata' in response.keys() and response['ResponseMetadata']['HTTPStatusCode'] == 200:
                print('Send email errors saved in s3://%s/%s' % (bucket, logfile_key))
        except Exception as e:
            print(e)
            raise e
        # Reset publish error log
        send_errors = []


if __name__ == "__main__":
    json_content = json.loads(open('event.json', 'r').read())
    lambda_handler(json_content, None)
