#!/usr/bin/env bash

app_name=$1
if [ -f $app_name ] ; then
    echo "Project name not specified."
    exit 1
fi

# Start creating project skeleton
app_root=$app_name/$app_name
mkdir -p $app_root
mkdir $app_root/static
mkdir $app_root/static/img
mkdir $app_root/static/css
mkdir $app_root/static/js
mkdir $app_root/templates

echo "{% extends \"layout.html\" %}
{% block body %}
{% endblock %}
" > $app_root/templates/home.html

echo "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"
        \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">

<html xmlns=\"http://www.w3.org/1999/xhtml\">
<head>
    <title>$app_name</title>
    <link rel=stylesheet type=text/css href=\"{{ url_for('static', filename='css/style.css') }}\">
</head>
<body>
<div class=page>
    <h1>Welcome to $app_name.</h1>

    <div class=nav>
    </div>
    {% for message in get_flashed_messages() %}
    <div class=flash>{{ message }}</div>
    {% endfor %}
    {% block body %}{% endblock %}
</div>
</body>
</html>
" > $app_root/templates/layout.html

echo "body            { font-family: sans-serif; background: #eee; }
" > $app_root/static/css/style.css

echo "from db_models import db
from flask import Flask
app = Flask(__name__)

import $app_name.views
db.init_app(app)
" > $app_root/__init__.py

echo "# configuration
DEBUG = False
SECRET_KEY = 'Some good random code here'
SQLALCHEMY_DATABASE_URI = 'mysql://username:password@localhost/database_name'
" > $app_root/configuration.py

echo "from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Test(db.Model):
    __tablename__ = 'test'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String)
    value = db.Column(db.Integer)

    def __init__(self, test_id, name, value):
        self.id = test_id
        self.name = name
        self.value = value

" > $app_root/db_models.py

echo "from flask import render_template, flash

from $app_name import app
from api.views import api_blueprint

# Register blueprints
app.register_blueprint(api_blueprint, url_prefix='/api')

app.config.from_pyfile('configuration.py')


@app.route('/')
def home():
    return render_template('home.html')


@app.errorhandler(404)
def page_not_found(e):
    flash('Sorry, nothing at this URL.')
    return render_template('home.html'), 404, e

" > $app_root/views.py

echo "from $app_name import app

if __name__ == '__main__':
    app.run(debug=True)

" > $app_name/runserver.py

api_root=$app_root/api
mkdir $api_root
mkdir $api_root/static
mkdir $api_root/static/img
mkdir $api_root/static/css
mkdir $api_root/static/js
mkdir $api_root/templates

touch $api_root/__init__.py
echo "from flask import Blueprint
from flask_restful import Resource, Api

# Blueprint
api_blueprint = Blueprint('api_blueprint', __name__, template_folder='templates', static_folder='static')
api = Api(api_blueprint)


class Version(Resource):
    def get(self):
        return {'version': '1.0.4'}

api.add_resource(Version, '/version')

" > $api_root/views.py



