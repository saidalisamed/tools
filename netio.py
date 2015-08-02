#!/usr/bin/env python
# coding: utf8

import subprocess
from time import sleep

interface = 'en0'


def size_readable(num, suffix='b'):
    for unit in ['','k','m','g','t','p','e','z']:
        if abs(num) < 1024.0:
            return "%.2f %s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.2f %s%s" % (num, 'i', suffix)


def get_bytes(interface_name):
    proc = subprocess.Popen(['netstat -I %s -ib | grep -e "%s" -m 1' % (interface_name, interface_name)],
                            stdout=subprocess.PIPE, shell=True)
    (out, error) = proc.communicate()
    stats_split = out.split()
    rx_bytes = stats_split[6]
    tx_bytes = stats_split[9]
    return [rx_bytes, tx_bytes]

bytes_before = get_bytes(interface)
sleep(1)
bytes_now = get_bytes(interface)

bits_received = (float(bytes_now[0])-float(bytes_before[0]))*8
bits_transmitted = (float(bytes_now[1])-float(bytes_before[1]))*8
print(u'⋀ %s/s\n⋁ %s/s' % (size_readable(bits_transmitted), size_readable(bits_received)))