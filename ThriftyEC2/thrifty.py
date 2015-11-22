#!/usr/bin/python

#########################################################################
# This script can be run on schedule to stop unwanted running instances #
# This is based on boto SDK and ~/.boto should be configured with       #
# access key and secret key. Add 'noshut' keyword in Name tag of the    #
# instance to prevent the script from stopping it.                      #
#########################################################################

import boto.ec2

no_shut_keyword = 'noshut'

connection = boto.ec2.connect_to_region("us-east-1")
for region in connection.get_all_regions():
    print 'Looking for running EC2 instances in region: {}'.format(region.name)
    connection = boto.ec2.connect_to_region(region.name)
    for instance in connection.get_only_instances():
        if instance.state == 'running':
            if no_shut_keyword not in instance.tags['Name']:
                print 'Stopping running instance: {} ({})'.format(instance.id, instance.tags['Name'])
                result = instance.stop()
                if result is not None:
                    print 'Could not stop instance {}'.format(instance.id)
