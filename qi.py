#!/usr/bin/env python

# Launches and terminates AWS ec2 instances quickly using CloudFormation.
# Date: 01 August 2015
# Author: Said Ali Samed

import getopt
import sys
import json
from os.path import expanduser
from time import sleep
from botocore.exceptions import NoCredentialsError

try:
    import boto3
except:
    print('Module \'boto3\' missing. Install by running \'pip install boto3\'')
    print('If you don\'t have pip, install it from https://pip.pypa.io/en/latest/installing.html')
    exit(2)

conf_file = expanduser("~") + '/.qi.conf'
script_name = 'qi.py'
os_list = tuple('amazon-linux nat-instance ubuntu redhat-linux windows-2012 windows-2008'.split())


def main():
    option_list = 'region= type= role= key= volume= ami= bootstrap='.split()
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], '', option_list)
    except:
        usage()
        sys.exit(2)
    if len(args) > 0:
        if args[0] == 'configure':
            configure()
        elif args[0] in os_list:
            try:
                launch(opts, args[0])
            except NoCredentialsError:
                suggest_credentials()
            except:
                troubleshoot()
        elif args[0] == 'help':
            usage()
        else:
            usage()
    else:
        usage()


def usage():
    print("""
Usage: ./%s [os|help|configure] [--region|--type|--role|--key|--volume|--ami|--bootstrap]

  os          : amazon-linux | nat-instance | redhat-linux | ubuntu | windows-2012 | windows-2008
  help        : prints this help
  configure   : configures quick instance.

  --region    : name of AWS region
  --type      : ec2 instance type
  --role      : ec2 instance role name
  --key       : ssh key name
  --volume    : ec2 instance root volume size in GB
  --ami       : ec2 instance ami id for the given selected AWS region
  --bootstrap : any shell command to configure instance at boot

Examples:
  ./%s amazon-linux                              : Launches an Amazon Linux ec2 instance
  ./%s configure                                 : Configure qi
  ./%s ubuntu --bootstrap "<shell commands>"     : Bootstrap instance with shell commands

""" % (script_name, script_name, script_name, script_name))


def configure():
    prompts = [
        {'question':'Specify AWS region: ', 'id':'region'},
        {'question':'Default instance type: ', 'id':'type'},
        {'question':'Instance profile name: ', 'id':'role'},
        {'question':'SSH key name for Linux instances: ', 'id':'key'},
        {'question':'SSH key name for Windows instances: ', 'id':'key-windows'},
        {'question':'Default root volume size in GB: ', 'id':'volume'},
        {'question':'AMI ID for Amazon Linux: ', 'id':'ami-amazon-linux'},
        {'question':'AMI ID for NAT instance: ', 'id':'ami-nat-instance'},
        {'question':'AMI ID for Ubuntu: ', 'id':'ami-ubuntu'},
        {'question':'AMI ID for Redhat Linux: ', 'id':'ami-redhat-linux'},
        {'question':'AMI ID for Windows 2012: ', 'id':'ami-windows-2012'},
        {'question':'AMI ID for Windows 2008: ', 'id':'ami-windows-2008'}
    ]
    config = {}
    for prompt in prompts:
        while True:
            response = raw_input(prompt['question'])
            if response.strip(): break
        config[prompt['id']] = response.strip()
    json.dump(config, open(conf_file, 'w'))


def load_conf():
    try:
        saved_conf = json.load(open(conf_file))
    except:
        print('Quick instance not configured. Please run \'%s configure\'.' % script_name)
        sys.exit(2)
    return saved_conf


def get_instance_properties(opts, stack_name):
    saved_conf = load_conf()
    for opt in opts:
        # add/replace saved conf with user supplied options
        if opt[0][2:] == 'bootstrap':
            saved_conf[opt[0][2:]] = opt[1]
        if opt[0][2:] in saved_conf:
            saved_conf[opt[0][2:]] = opt[1]
            if opt[0][2:] == 'key': saved_conf['key-windows'] = opt[1]
    # configure dictionary based on stack type
    if stack_name in ['amazon-linux', 'nat-instance']:
        saved_conf['device'] = '/dev/xvda'
    else:
        saved_conf['device'] = '/dev/sda1'
    if 'windows' in stack_name:
        saved_conf['user'] = 'Administrator'
        saved_conf['key'] = saved_conf['key-windows']
    elif 'ubuntu' in stack_name:
        saved_conf['user'] = 'ubuntu'
    else:
        saved_conf['user'] = 'ec2-user'
    saved_conf['ami'] = saved_conf['ami-'+stack_name]
    if not 'bootstrap' in saved_conf:
        saved_conf['bootstrap'] = ''
    return saved_conf


def launch(opts, stack_name):
    prop = get_instance_properties(opts, stack_name)
    region = prop['region']
    print('Launching instance %s... ' % stack_name)
    output = create_stack(stack_name, get_template(prop, stack_name), region)
    if output == 'STACK_ALREADY_EXISTS':
        status = get_stack_state(stack_name, region).stack_status
        if status == 'CREATE_COMPLETE':
            get_instance_detail(get_instance_id(stack_name, region), stack_name, prop['key'], prop['user'], region)
        prompt = raw_input('Instance \'%s\' already exists. Would you like to terminate it? ' % stack_name)
        if prompt in ['Y','y']:
            delete_stack(stack_name, region)
    elif 'arn:aws:cloudformation' in output:
        while True:
            status = get_stack_state(stack_name, region).stack_status
            if status == 'CREATE_COMPLETE':
                print('Instance created successfully.')
                get_instance_detail(get_instance_id(stack_name, region), stack_name, prop['key'], prop['user'], region)
                break
            elif status == 'CREATE_FAILED' or 'ROLLBACK' in status:
                print('Failed to create instance \'%s\'. Review error in CloudFormation console.' % stack_name)
                break
            sleep(5)


def create_stack(stack_name, template, region):
    try:
        cf = boto3.client('cloudformation', region_name=region)
        response = cf.create_stack(StackName=stack_name, TemplateBody=template)
    except:
        return 'STACK_ALREADY_EXISTS'
    if 'StackId' in response:
        return response['StackId']
    else:
        return


def delete_stack(stack_name, region):
    try:
        cf = boto3.client('cloudformation', region_name=region)
        print('Terminating %s...' % stack_name)
        response = cf.delete_stack(StackName=stack_name)
    except:
        print('Failed to terminate %s. Review error in CloudFormation console.' % stack_name)
        return response
    return response


def get_stack_state(stack_name, region):
    try:
        cf = boto3.resource('cloudformation', region_name=region)
        stack = cf.Stack(stack_name)
    except:
        print('Failed to get stack state.')
        return
    return stack


def get_instance_id(stack_name, region):
    state = get_stack_state(stack_name, region)
    stack_outputs = state.outputs
    if stack_outputs and len(stack_outputs) > 0 and stack_outputs[0]['OutputKey'] == 'InstanceId':
        return stack_outputs[0]['OutputValue']
    else:
        return


def get_instance_ip(instance_id, region):
    try:
        ec2 = boto3.resource('ec2', region_name=region)
        instance = ec2.Instance(instance_id)
    except:
        print("Failed to get instance ip address.")
        return
    return instance.public_ip_address


def get_instance_detail(instance_id, stack_name, key, username, region):
    print('Getting instance details... ')
    instance_ip = get_instance_ip(instance_id, region)
    print('%s -> %s\n' % (instance_id, instance_ip))
    if 'windows' in stack_name:
        print('RDP to the instance by decrypting Administrator password in management console.\n')
        print('Paste the following command in Start -> Run:')
        print('mstsc /v %s:3389\n' % instance_ip)
    else:
        print('SSH into the instance using command:')
        print('ssh -i ~/.ssh/%s.pem %s@%s\n' % (key, username, instance_ip))


def get_template(prop, stack_name):
    #/TODO: add native json instead
    template = """
{
  "AWSTemplateFormatVersion" : "2010-09-09",
  "Description" : "Launched using quick instance script.",
  "Resources" : {
    "InstanceSecurityGroup" : {
      "Type" : "AWS::EC2::SecurityGroup",
      "Properties" : {
        "GroupDescription" : "Enable required inbound ports",
        "SecurityGroupIngress" : [
            { "IpProtocol" : "tcp", "FromPort" : "22", "ToPort" : "22", "CidrIp" : "0.0.0.0/0" },
            { "IpProtocol" : "tcp", "FromPort" : "3389", "ToPort" : "3389", "CidrIp" : "0.0.0.0/0" },
            { "IpProtocol" : "tcp", "FromPort" : "80", "ToPort" : "80", "CidrIp" : "0.0.0.0/0" },
            { "IpProtocol" : "tcp", "FromPort" : "443", "ToPort" : "443", "CidrIp" : "0.0.0.0/0" }
        ]
      }
    },
    "Ec2Instance" : {
      "Type" : "AWS::EC2::Instance",
      "Properties" : {
          "BlockDeviceMappings" : [
               {
                  "DeviceName" : "%s",
                  "Ebs" : {
                     "VolumeSize" : %s,
                     "VolumeType" : "gp2"
                  }
               }
            ],
          "ImageId" : "%s",
          "InstanceType" : "%s",
          "KeyName" : "%s",
          "SecurityGroupIds" : [ {"Ref" : "InstanceSecurityGroup"} ],
          "Tags" : [ {"Key" : "Name", "Value" : "%s"} ],
          "UserData" : {"Fn::Base64" : "#!/bin/bash\\n%s"},
          "IamInstanceProfile" : "%s"
      }
    }
  },
  "Outputs" : {
    "InstanceId" : {
      "Value" : { "Ref" : "Ec2Instance" },
      "Description" : "Instance Id of newly created instance"
    }
  }
}
""" % (prop['device'], prop['volume'], prop['ami'], prop['type'], prop['key'],
       stack_name, prop['bootstrap'], prop['role'])
    return template


def suggest_credentials():
    print('AWS credentials not found. You can create the credential file in ~/.aws/credentials')
    print('Follow http://boto3.readthedocs.org/en/latest/guide/quickstart.html#configuration for details.')


def troubleshoot():
    print('An error occurred while launching instance. Ensure you have entered correct settings during configuration.')
    print('Run \'%s configure\' to reconfigure or specify correct options as parameters.' % script_name)


if __name__ == "__main__":
    main()
