HowTo
=====

qi.sh ( Quick Instance ) examples:
----------------------------------

Launch Ubuntu instance with Apache Tomcat7 configured:

    ./qi.sh ubuntu "wget https://raw.githubusercontent.com/saidalisamed/HowTo/master/tomcat7_java8_ubuntu14.04_install.sh -O /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh"

Launch Ubuntu instance with Apache (wsgi) and deploy a sample Python Flask application:

    ./qi.sh ubuntu "wget https://raw.githubusercontent.com/saidalisamed/HowTo/master/flask_deploy.sh -O /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh example_app https://github.com/deis/example-python-flask/archive/master.zip"
    
Launch Amazon Linux with LAMP stack configured:

    ./qi.sh amazon-linux "yum update -y && yum groupinstall -y 'Web Server' 'MySQL Database' 'PHP Support' && yum install -y php-mysql && service httpd start && chkconfig httpd on && groupadd www && usermod -a -G www ec2-user && chown -R root:www /var/www && chmod 2775 /var/www && find /var/www -type d -exec chmod 2775 {} + && find /var/www -type f -exec chmod 0664 {} + && echo '<?php phpinfo(); ?>' > /var/www/html/phpinfo.php"

Launch Amazon Linux and install/configure a CRM software (SuiteCRM):

    ./qi.sh amazon-linux "yum update -y && yum groupinstall -y 'Web Server' 'MySQL Database' 'PHP Support' && yum install -y php-mysql && yum install -y php-mbstring && service httpd start && chkconfig httpd on && chkconfig mysqld on && groupadd www && usermod -a -G www ec2-user && chown -R root:www /var/www && chmod 2775 /var/www && find /var/www -type d -exec chmod 2775 {} + && find /var/www -type f -exec chmod 0664 {} + && wget -O /tmp/crm.zip  http://downloads.sourceforge.net/project/suitecrm/suitecrm-7.2.1.zip && mkdir /tmp/crm && unzip /tmp/crm.zip -d /tmp/crm/ && shopt -s dotglob nullglob && mv /tmp/crm/*/* /var/www/html/ && chown -R apache:www /var/www/html/ && /etc/init.d/mysqld restart"

Launch Ubuntu instance and install/configure SuiteCRM with HHVM and nginx:

    ./qi.sh ubuntu "wget https://raw.githubusercontent.com/saidalisamed/HowTo/master/nginx_hhvm_suitecrm_ubuntu14.04_install.sh -O /tmp/install.sh && chmod +x /tmp/install.sh && /tmp/install.sh"

To terminate, run the same command again:

    ./qi.sh ubuntu
    ./qi.sh amazon-linux

