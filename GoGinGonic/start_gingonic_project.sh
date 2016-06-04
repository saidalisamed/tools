#!/usr/bin/env bash

# Creates a Go gingonic project skeleton.
# Also includes sql and sample routes.

project=$1
if [ -f $project ] ; then
    echo "Please specify a project name."
    exit 1
fi

# Start creating project skeleton
echo "Creating project skeleton..."

mkdir $project
resources=$project/resources
mkdir $resources
mkdir $resources/static
mkdir $resources/static/img
mkdir $resources/static/css
mkdir $resources/static/js
mkdir $resources/templates
mkdir $resources/notes

echo "package main

import (
	\"database/sql\"
	\"flag\"
	\"github.com/gin-gonic/gin\"
	_ \"github.com/go-sql-driver/mysql\"
	\"gopkg.in/gorp.v1\"
	\"log\"
	\"net/http\"
	\"runtime\"
	\"time\"
)

// Database models
type Products struct {
	Id             int64     \`db:\"id\" json:\"id\"\`
	Name           string    \`db:\"name\" json:\"name\"\`
	Date           time.Time \`db:\"date\" json:\"date\"\`
}

// Global variables
var dbmap *gorp.DbMap

const dbUser = \"secret\"
const dbPass = \"secret\"
const dbName = \"secret\"

// Database connection
func initDb(socketFile string) *gorp.DbMap {

    db, err := sql.Open(\"mysql\", dbUser+\":\"+dbPass+\"@unix(\"+socketFile+\")/\"+dbName+\"?parseTime=true\")
	checkErr(err, \"sql.Open failed\")
	dbmap := &gorp.DbMap{Db: db, Dialect: gorp.MySQLDialect{\"MyISAM\", \"UTF8\"}}
	dbmap.AddTableWithName(Products{}, \"products\").SetKeys(true, \"Id\")

	return dbmap
}

func checkErr(err error, msg string) {

	if err != nil {
		log.Panic(msg, err)
	}
}

func main() {

	// Performance and deployment related settings
	runtime.GOMAXPROCS(runtime.NumCPU())
	gin.SetMode(gin.DebugMode)

	// Initialize gin request router
	router := gin.Default()
	router.LoadHTMLGlob(\"resources/templates/*\")
	router.Static(\"/static\", \"resources/static\")

	// Main website pages
	mainSection := router.Group(\"/\")
	{
		mainSection.GET(\"/\", index)
		mainSection.GET(\"/about\", about)
		mainSection.GET(\"/product/:name\", product)
	}

	// /api pages
	api := router.Group(\"/api\")
	{
		api.GET(\"/\", apiIndex)
		api.GET(\"/product/:name\", apiProduct)
        api.GET(\"/list\", apiList)
	}

    // Connect to mysql using unix socket for performance using --dbsocket=/var/run/...mysql.sock
    // When deployed you may want to listen on unix socket instead of tcp using --unixsocket
	dbsocketPtr := flag.String(\"dbsocket\", \"/tmp/mysql.sock\", \"MySQL socket file path\")
	unixsocketPtr := flag.Bool(\"unixsocket\", false, \"Application to listen on unix socket or tcp 8080\")
	flag.Parse()

	// Connect to database
    // Uncomment below if require database backend
	dbmap = initDb(*dbsocketPtr)

	// Listen on unix socket or tcp based on commandline flags
	if *unixsocketPtr {
		router.RunUnix(\"/tmp/$project.sock\")
	} else {
		router.Run(\"127.0.0.1:8080\")
	}
}

// ------------- Main website functions ------------

func index(c *gin.Context) {

	c.HTML(http.StatusOK, \"index.html\", gin.H{
		\"title\":    \"$project Home\",
	})
}

func about(c *gin.Context) {

	c.HTML(http.StatusOK, \"about.html\", gin.H{
		\"title\":    \"About $project\",
	})
}

func product(c *gin.Context) {

    name := c.Param(\"name\")
	c.HTML(http.StatusOK, \"product.html\", gin.H{
		\"title\":    \"Product detail\",
		\"name\":     name,
	})
}

// ------------- API functions ------------

func apiIndex(c *gin.Context) {

	c.String(http.StatusOK, \"$project API Endpoint\")
}

func apiProduct(c *gin.Context) {

    name := c.Param(\"name\")
	c.JSON(http.StatusOK, gin.H{
		\"name\":     name,
	})
}

func apiList(c *gin.Context) {

    var products []Products
    dbmap.Select(&products, \"SELECT * FROM products\")
	c.JSON(http.StatusOK, gin.H{
		\"name\":     gin.H{\"products\": &products},
	})
}
" > $project/app.go

echo "{{ define \"top\" }}
<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <title>{{ .title }}</title>
</head>
<body>
{{ end }}


{{ define \"bottom\" }}
</body>
</html>
{{ end }}" > $resources/templates/common.tmpl.html

echo "{{ template \"top\" . }}

$project Homepage

{{ template \"bottom\" }}" > $resources/templates/index.html

echo "{{ template \"top\" . }}

About $project

{{ template \"bottom\" }}" > $resources/templates/about.html

echo "{{ template \"top\" . }}

Viewing product: {{ .name }}

{{ template \"bottom\" }}" > $resources/templates/product.html

echo "$project project skeleton creation complete."

echo "
Deployment Notes
----------------
1. Build $project for the destination architecture such as amd64:

   env GOOS=linux GOARCH=amd64 go build -v $project/app.go

2. Copy your project $project excluding the Go source app.go to your server (Ubuntu) in /var/www/html/$project.

3. Create a startup script to launch the app.

   sudo vim /etc/init/$project.conf
   # add the following
   
#################
# file: /etc/init/$project.conf
description \"$project web app\"

start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
  cd /var/www/html/$project/
  exec sudo -u www-data /var/www/html/$project/app -unixsocket -dbsocket=/var/run/mysqld/mysqld.sock >> /var/log/$project/access.log 2>&1
end script
#################

   mkdir /var/log/$project
   sudo start $project
   sudo vim /etc/logrotate.d/$project
   # add the following

#################
/var/log/$project/*.log {
        weekly
        missingok
        rotate 10
        compress
        delaycompress
        notifempty
        create 0640 root root
        sharedscripts
        postrotate
    		restart -q $project
        endscript
}
#################

4. Configure nginx as your application frontend.

   sudo vim /etc/nginx/sites-available/$project.conf
   # add the following

#################
upstream $project {
    server unix:/tmp/$project.sock;
}

server {
    listen 80;
    server_name www.example.com;
    access_log /var/log/nginx/$project_access.log;
    error_log /var/log/nginx/$project_error.log error;
    location /static/ { alias /var/www/html/$project/resources/static/; }
    location / {
        proxy_pass http://$project;
    }
#################

   sudo ln -s /etc/nginx/sites-available/$project.conf /etc/nginx/sites-enabled
   sudo service nginx reload

" > $resources/notes/deployment_notes.txt
