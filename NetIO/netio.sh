#!/bin/bash
 
# This shell script shows the network speed, both received and transmitted.
  
# Global variables
interface=en0
received_bytes=""
old_received_bytes=""
transmitted_bytes=""
old_transmitted_bytes=""
 
# This function parses netstat output and stores it into received and transmitted bytes variables.
get_bytes()
{
	received_bytes=`netstat -ib | grep -e "$interface" -m 1 | awk '{print $7}'` # bytes in
	transmitted_bytes=`netstat -ib | grep -e "$interface" -m 1 | awk '{print $10}'` # bytes out
}
 
# Function which calculates the speed using actual and old byte number.
# Speed is shown in KByte per second when greater than or equal to 1 KByte per second.
# This function should be called each second.
get_velocity()
{
	value=$1
	old_value=$2
 
	let vel=($value-$old_value)*8
	
	if [ $vel -ge 1048576 ];
	then
		mbits=`echo "scale=2; $vel/1024/1024" | bc -l`
		echo "$mbits mb/s";
	elif [ $vel -ge 1024 ];
	then
		let kbits=$vel/1024
		echo "$kbits kb/s";
	else
		echo "$vel b/s";
	fi
}
 
# Gets initial values.
get_bytes
old_received_bytes=$received_bytes
old_transmitted_bytes=$transmitted_bytes
 
# Waits for one second.
sleep 1;
 
# Get new transmitted and received byte number values.
get_bytes

# Calculates speeds.
vel_recv=$(get_velocity $received_bytes $old_received_bytes)
vel_trans=$(get_velocity $transmitted_bytes $old_transmitted_bytes)

# Shows results in the console.
echo "⋀  $vel_trans"
echo "⋁  $vel_recv"
