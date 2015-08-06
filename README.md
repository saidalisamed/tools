Quick Instance
==============
Quick Instance 'qi.py' quickly launches, deploys application and terminates AWS ec2 instances using CloudFormation. 
This is useful when a disposable ec2 instance is needed to quickly test or deploy an application on a supported OS.

Examples:
--------
Launch a vanilla Amazon Linux ec2 instance without bootstrapping it:

    ./qi.py amazon-linux
    
Launch Ubuntu ec2 instance with Apache Tomcat7 configured:

    ./qi.py ubuntu --bootstrap "wget https://raw.githubusercontent.com/saidalisamed/tools/master/tomcat7_java8_ubuntu14.04_install.sh -O /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh"

Launch Ubuntu ec2 instance with Apache (wsgi) and deploy a sample Python Flask application:

    ./qi.py ubuntu --bootstrap "wget https://raw.githubusercontent.com/saidalisamed/tools/master/flask_deploy.sh -O /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh example_app https://github.com/deis/example-python-flask/archive/master.zip"
    
Launch Amazon Linux with LAMP stack configured:

    ./qi.py amazon-linux --bootstrap "yum update -y && yum groupinstall -y 'Web Server' 'MySQL Database' 'PHP Support' && yum install -y php-mysql && service httpd start && chkconfig httpd on && groupadd www && usermod -a -G www ec2-user && chown -R root:www /var/www && chmod 2775 /var/www && find /var/www -type d -exec chmod 2775 {} + && find /var/www -type f -exec chmod 0664 {} + && echo '<?php phpinfo(); ?>' > /var/www/html/phpinfo.php"

Launch Amazon Linux and install/configure a CRM software (SuiteCRM):

    ./qi.py amazon-linux --bootstrap "yum update -y && yum groupinstall -y 'Web Server' 'MySQL Database' 'PHP Support' && yum install -y php-mysql && yum install -y php-mbstring && service httpd start && chkconfig httpd on && chkconfig mysqld on && groupadd www && usermod -a -G www ec2-user && chown -R root:www /var/www && chmod 2775 /var/www && find /var/www -type d -exec chmod 2775 {} + && find /var/www -type f -exec chmod 0664 {} + && wget -O /tmp/crm.zip  http://downloads.sourceforge.net/project/suitecrm/suitecrm-7.2.1.zip && mkdir /tmp/crm && unzip /tmp/crm.zip -d /tmp/crm/ && shopt -s dotglob nullglob && mv /tmp/crm/*/* /var/www/html/ && chown -R apache:www /var/www/html/ && /etc/init.d/mysqld restart"

Launch Ubuntu instance and install/configure SuiteCRM with HHVM and nginx:

    ./qi.py ubuntu --bootstrap "wget https://raw.githubusercontent.com/saidalisamed/tools/master/nginx_hhvm_suitecrm_ubuntu14.04_install.sh -O /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh"

Launch six difference ec2 instances simultaneously:
    
    for os in amazon-linux nat-instance ubuntu redhat-linux windows-2008 windows-2012; do ./qi.py $os & done

Launch Ubuntu ec2 instance with a 100GB root volume size by overriding the default configuration:
    
    ./qi.py ubuntu --volume 100

To terminate, run the same command again:

    ./qi.py ubuntu
    ./qi.py amazon-linux

Installation:
------------
Installation on Linux and Mac OSX:

    curl -o qi.py https://raw.githubusercontent.com/saidalisamed/tools/master/qi.py
    chmod +x qi.py
    
For installation on Windows, save [this](https://raw.githubusercontent.com/saidalisamed/tools/master/qi.py).

To install boto3 on windows and launching an ec2 instance:

    C:\Python27\python.exe -m pip install boto3
    C:\Python27\python.exe qi.py amazon-linux
    
Configuration:
-------------
Run 'configure' when running for the first time to configure quick instance.

    ./qi.py configure


Requirements:
------------
- Python 2.7 or above.
- Boto3 python module.
- Python pip required to install boto3 module.
- AWS credentials in ~/.aws/credentials or ec2 instance role with appropriate IAM permissions. Follow this [guide](http://blogs.aws.amazon.com/security/post/Tx3D6U6WSFGOK2H/A-New-and-Standardized-Way-to-Manage-Credentials-in-the-AWS-SDKs) to set up AWS credentials.