#!/bin/bash

# ensure user is root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root. Use 'sudo ./<script>'." 1>&2
   exit 1
fi

# install oracle java8
apt-add-repository ppa:webupd8team/java -y
apt-get update
echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
apt-get install -y oracle-java8-installer

# install and configure tomcat7
apt-get install -y tomcat7
echo "JAVA_HOME=/usr/lib/jvm/java-8-oracle" >> /etc/default/tomcat7
service tomcat7 restart

# make tomcat available on port 80
iptables -A INPUT -i eth0 -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport 8080 -j ACCEPT
iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 8080
sh -c "iptables-save > /etc/iptables.rules"
echo "pre-up iptables-restore < /etc/iptables.rules" >> /etc/network/interfaces.d/eth0.cfg 

# deploy a war file
cp /home/ubuntu/website.war /var/lib/tomcat7/webapps/

# finish
echo "Installation completed."
