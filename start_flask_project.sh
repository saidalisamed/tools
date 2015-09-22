#!/usr/bin/env bash

# Creates a flask project skeleton that is modular and well suited for larger projects.
# Also includes SQLAlchemy and flask restful API samples in blueprints.

project=$1
if [ -f $project ] ; then
    echo "Project name not specified."
    exit 1
fi

flask_install_commands="
- Run following commands to set up flask virtualenv if development workstation is non-linux. (Ubuntu)

# Prepare for flask virtualenv
sudo apt-get install python-virtualenv
sudo apt-get install libmysqld-dev
sudo apt-get install python-dev

# Install flask in virtualenv
cd /var/www/html/
virtualenv $project/flask
$project/flask/bin/pip install flask
$project/flask/bin/pip install flask-sqlalchemy
$project/flask/bin/pip install flask-restful
$project/flask/bin/pip install mysql-python
$project/flask/bin/pip install flup"

apache_install_commands="
- Run following commands to install configure apache web server. (Ubuntu)

# Install apache
sudo apt-get install apache2

# Install modules
sudo apt-get install libapache2-mod-fcgid
sudo apt-get install libapache2-mod-wsgi
"

# Start creating project skeleton
echo "Creating project skeleton..."

mkdir $project
app=$project/app
mkdir $app
mkdir $app/static
mkdir $app/static/img
mkdir $app/static/css
mkdir $app/static/js
mkdir $app/templates

echo "# configuration
DEBUG = False
SECRET_KEY = 'Run in interpreter for strong secret: import os;os.urandom(24)'
SQLALCHEMY_DATABASE_URI = 'mysql://username:password@localhost/database_name'" > $project/config.py

echo "#!flask/bin/python

from app import app

if __name__ == '__main__':
    app.run(debug=True)" > $project/run.py
chmod +x $project/run.py

echo "#!flask/bin/python

from flup.server.fcgi import WSGIServer
from app import app


class ScriptNameStripper(object):
    def __init__(self, the_app):
        self.app = the_app

    def __call__(self, environ, start_response):
        environ['SCRIPT_NAME'] = ''
        return self.app(environ, start_response)

app = ScriptNameStripper(app)

if __name__ == '__main__':
    WSGIServer(app).run()" > $project/run.fcgi
chmod +x $project/run.fcgi

echo "
$apache_install_commands

# Enable apache modules rewrite and fcgid
sudo a2enmod rewrite
sudo a2enmod fcgid

# Apache virtualhost configuration

<VirtualHost *>
    #ServerName example.com
    #ServerAlias www.example.com
    ServerAdmin webmaster@localhost
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
    DocumentRoot /var/www/html/$project

    <Directory /var/www/html/$project>
        Order deny,allow
        Allow from all
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

$flask_install_commands" > $project/fcgi_deployment_readme.txt

echo "activate_this = '/var/www/html/$project/flask/bin/activate_this.py'
execfile(activate_this, dict(__file__=activate_this))

import sys
sys.path.append('/var/www/html/$project')

from run import app as application" > $project/run.wsgi

echo "
$apache_install_commands

# Enable apache modules rewrite and wsgi
sudo a2enmod rewrite
sudo a2enmod wsgi

$flask_install_commands

# Sample Apache wsgi virtual host configuration. Remove the .htaccess file if using wsgi
<VirtualHost *:80>
    #ServerName example.com
    #ServerAlias www.example.com
    ServerAdmin webmaster@localhost
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined

    WSGIDaemonProcess $project user=www-data group=www-data threads=50
    WSGIScriptAlias / /var/www/html/$project/run.wsgi

    <Directory /var/www/html/$project>
        WSGIProcessGroup $project
        WSGIApplicationGroup %{GLOBAL}
        Order deny,allow
        Allow from all
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>" > $project/wsgi_deployment_readme.txt

echo "<IfModule mod_fcgid.c>
    AddHandler fcgid-script .py
    <Files ~ \"\.(fcgi|py|pyc)\">
        SetHandler fcgid-script
        Options +SymLinksIfOwnerMatch +ExecCGI
    </Files>
</IfModule>

<IfModule mod_rewrite.c>
    Options +SymLinksIfOwnerMatch
    RewriteEngine On
    RewriteBase /
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ run.fcgi/\$1 [QSA,L]
</IfModule>" > $project/.htaccess

echo "{% extends \"layout.html\" %}
{% block body %}
{% endblock %}" > $app/templates/home.html

echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"
        \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">

<html xmlns=\"http://www.w3.org/1999/xhtml\">
<head>
    <title>$project</title>
    <link rel=stylesheet type=text/css href=\"{{ url_for('static', filename='css/style.css') }}\">
</head>
<body>
<div class=page>
    <h1>Welcome to $project.</h1>

    <div class=nav>
    </div>
    {% for message in get_flashed_messages() %}
    <div class=flash>{{ message }}</div>
    {% endfor %}
    {% block body %}{% endblock %}
</div>
</body>
</html>" > $app/templates/layout.html

echo "body            { font-family: sans-serif; background: #eee; }
.flash          { background: #cee5F5; padding: 0.5em; border: 1px solid #aacbe2; }" > $app/static/css/style.css

echo "from flask import Flask
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
app.config.from_object('config')
db = SQLAlchemy(app)

from app import views, models" > $app/__init__.py

echo "from app import db


class Test(db.Model):
    __tablename__ = 'test'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String)
    value = db.Column(db.Integer)

    def __init__(self, test_id, name, value):
        self.id = test_id
        self.name = name
        self.value = value" > $app/models.py

echo "from flask import render_template, flash
from app import app
from api.views import api_blueprint

# Register blueprints
app.register_blueprint(api_blueprint, url_prefix='/api')


@app.route('/')
def home():
    return render_template('home.html')


@app.errorhandler(404)
def page_not_found(e):
    flash('Sorry, nothing at this URL.')
    return render_template('home.html'), 404, e" > $app/views.py

api=$app/api
mkdir $api
mkdir $api/static
mkdir $api/static/img
mkdir $api/static/css
mkdir $api/static/js
mkdir $api/templates

touch $api/__init__.py
echo "from flask import Blueprint
from flask_restful import Resource, Api

# Blueprint
api_blueprint = Blueprint('api_blueprint', __name__, template_folder='templates', static_folder='static')
api = Api(api_blueprint)


class Version(Resource):
    def get(self):
        return {'version': '1.0'}
api.add_resource(Version, '/version')


@api_blueprint.route('/')
def home():
    return 'API home'" > $api/views.py

# Flask in virtualenv
echo "Setting up flask in virtualenv..."

virtualenv $project/flask
$project/flask/bin/pip install flask
$project/flask/bin/pip install flask-sqlalchemy
$project/flask/bin/pip install flask-restful
$project/flask/bin/pip install mysql-python
$project/flask/bin/pip install flup

echo "Project skeleton creation complete."
