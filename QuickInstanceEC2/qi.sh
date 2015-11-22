#!/bin/bash

# Launches and terminates ec2 instance quickly using generated CloudFormation template.

# Do not update
instance_os=$1
user_data=$2
pref_file="$(echo ~)/.qi_prefs.conf"
script_name="qi.sh"

# Functions
function get_template {
	template=$(cat <<EOF
{
  "AWSTemplateFormatVersion" : "2010-09-09",
  "Description" : "Launched using qi (quick instance) script.",
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
                  "DeviceName" : "$volume_device_name",
                  "Ebs" : {
                     "VolumeSize" : $volume_size,
					 "VolumeType" : "gp2"
                  }
               }
            ],
		  "ImageId" : "$ami_id",
		  "InstanceType" : "$instance_type",
		  "KeyName" : "$key_name",
		  "SecurityGroupIds" : [ {"Ref" : "InstanceSecurityGroup"} ],
		  "Tags" : [ {"Key" : "Name", "Value" : "$instance_os"} ],
		  "UserData" : {"Fn::Base64" : "#!/bin/bash\n$user_data"},
		  "IamInstanceProfile" : "$instance_profile"
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
EOF
	)
	
	echo $template
}

function set_preferences {
	questions=( 
	"region;Specify AWS region: " 
	"instance_type;Default instance type: " 
	"instance_profile;Instance profile name: " 
	"ssh_key_linux;SSH key name for Linux instances: " 
	"ssh_key_windows;SSH key name for Windows instances: " 
	"volume_size;Default root volume size: " 
	"ami_amazon_linux;AMI ID for Amazon Linux: " 
	"ami_nat_instance;AMI ID for NAT instance: " 
	"ami_ubuntu;AMI ID for Ubuntu: " 
	"ami_redhat_linux;AMI ID for Redhat Linux: "  
	"ami_windows_2012;AMI ID for Windows 2012: "  
	"ami_windows_2008;AMI ID for Windows 2008: "
	)
		
	# Save new prefs
	for i in "${questions[@]}" ; do
		IFS=';' read -ra items <<< "$i"
		#while [[ -z "$answer" ]] ; do
	    	read -p "${items[1]}" answer
		#done	
		
		# Add answers to array
		answers=(${answers[@]} "${items[0]}=$answer")
	done
	
	# Empty pref file 
	if [ -f $pref_file ] ; then 
		echo "Resetting existing preferences..."
		> $pref_file 
	fi

	# Write answers to prefs file
	for answered in "${answers[@]}" ; do
		echo "$answered" >> $pref_file
	done
	echo "New preferences saved."
	print_usage
}

function read_preferences {
	if [ -f $pref_file ] ; then
		source $pref_file
		
		if [[ $instance_os == "amazon-linux" ]] ; then
			volume_device_name="/dev/xvda"
			key_name=$ssh_key_linux
			ami_id=$ami_amazon_linux
			instance_user="ec2-user"
		elif [[ $instance_os == "nat-instance" ]] ; then
			volume_device_name="/dev/xvda"
			key_name=$ssh_key_linux
			ami_id=$ami_nat_instance
			instance_user="ec2-user"
		elif [[ $instance_os == "ubuntu" ]] ; then
			volume_device_name="/dev/sda1"
			key_name=$ssh_key_linux
			ami_id=$ami_ubuntu
			instance_user="ubuntu"
		elif [[ $instance_os == "redhat-linux" ]] ; then
			volume_device_name="/dev/sda1"
			key_name=$ssh_key_linux
			ami_id=$ami_redhat_linux
			instance_user="ec2-user"
		elif [[ $instance_os == "windows-2012" ]] ; then
			volume_device_name="/dev/sda1"
			key_name=$ssh_key_windows
			ami_id=$ami_windows_2012
			instance_user="Administrator"
		elif [[ $instance_os == "windows-2008" ]] ; then
			volume_device_name="/dev/sda1"
			key_name=$ssh_key_windows
			ami_id=$ami_windows_2008
			instance_user="Administrator"
		else
			echo "Invalid OS in parameter."
			print_usage
			exit 1;
		fi
		
	else
		echo "No preferences found. Setting up..."
		echo ""
		set_preferences
		exit 0;
	fi
}

function create_stack {
	output=$( { aws cloudformation create-stack --stack-name $instance_os --template-body "$(get_template)" --output text --region $region; } 2>&1 ) 
	#echo $output
}

function delete_stack {
	echo "Terminating $instance_os..."
	aws cloudformation delete-stack --stack-name $instance_os --region $region
}

function get_stack_state {
	state=$(aws cloudformation describe-stacks --stack-name $instance_os --output text  --region $region --query 'Stacks[*]' |grep 'CREATE_COMPLETE\|FAILED\|ROLLBACK')
	#echo $state
}

function get_instance_id {
	instance_id=$(aws cloudformation describe-stacks --stack-name $instance_os --output text --region $region --query 'Stacks[*].Outputs[*]' | awk '{ print $(8) }')
	#echo $instance_id
}

function get_instance_ip {
	ip_address=$(aws ec2 describe-instances --instance-ids $instance_id --output text  --region $region --query 'Reservations[*].Instances[*].PublicIpAddress')
	#echo $ip_address
}

function get_instance_detail {
	echo "Getting instance details... "
	get_instance_ip
	echo "$instance_id -> $ip_address"
	echo ""
	if [[ $instance_os = *"windows"* ]] ; then
		echo "RDP to the instance by decrypting Administrator password in management console."
	else
		echo "Connect to the instance using SSH:"
		echo "ssh -i ~/.ssh/$ssh_key_linux.pem $instance_user@$ip_address"
	fi
	echo ""
}

function print_usage {
	echo ""
	echo "Usage:"
	echo "Available OS parameters: [ amazon-linux | nat-instance | redhat-linux | ubuntu | windows-2012 | windows-2008 ]"
	echo ""
	echo "Examples:" 
	echo "$script_name amazon-linux                          : Launches an Amazon Linux ec2 instance"
	echo "$script_name configure                             : Configure qi preferences"
	echo "$script_name amazon-linux \"<shell command>\"        : Bootstrap instance with shell commands"
	echo ""

}

function detect_aws_cli {
	result=$( { aws --version; } 2>&1 )
	if [[ $? != 0 ]] ; then
		echo "AWS CLI not found. Please install and configure AWS CLI tools."
		exit 1;
	fi
}

# === Execution starts here ===

# Set up preferences
if [[ $1 == "configure" ]] ; then
	set_preferences
	exit 0
fi

# Read preferences
read_preferences

# Ensure aws cli is installed
detect_aws_cli

# Check for instance os in parameter
if [ -z $instance_os ] ; then
	echo "OS parameter not specified."
	print_usage
	exit 1;
fi

# === Checks done. Process request ===

# Run the create-stack cloudformation command
echo "Launching instance $instance_os... "
create_stack

# Exit if create stack failed or ask to delete if stack already exists
rc=$?
if [[ $rc != 0 ]] ; then
	if [[ $output == *"already exists"* ]] ; then
		# Get instance ssh info
		get_instance_id
		get_instance_detail
		
		# Offer user to delete the existing instance
		read -p "Would you like to terminate it? " answer
		case ${answer:0:1} in
			y|Y )
				delete_stack
			;;
			* )
				exit 0
			;;
		esac
	elif [[ $output == *"usage:"* ]] ; then
		echo ""
		echo "Failed to initiate $instance_os instance launch."
		echo "Run '$script_name configure' to fix configuration."
		echo ""
		exit 1
	else
		echo "Failed to initiate $instance_os instance launch."
		echo "Run '$script_name configure' to fix configuration."
		print_usage
	fi
	
	exit $rc
fi


# Query the new instance for its ip address
while (true); do
	get_stack_state
	
	if [[ $state == *"CREATE_COMPLETE"* ]] ; then
		echo "Instance launched successfully."
		echo ""
		# Creation has completed, getting instance details
		get_instance_id
		
		if [[ $instance_id == *"i-"* ]] ; then
			get_instance_detail
			exit 0
		else
			echo "Failed to get instance details."
			echo ""
			exit 1
		fi
		
	elif [[ $state == *"FAILED"* ]] || [[ $state == *"ROLLBACK"* ]] ; then
		echo "Instance creation failed."
		echo "Run '$script_name configure' to fix configuration."
		echo ""
		exit 1
	fi
		
	sleep 5;
done
