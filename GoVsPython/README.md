Go (gin-gonic) vs Python (flask)
================================
Web app performance test.


Go Code
-------
```go
package main

import (
	"github.com/gin-gonic/gin"
	"net/http"
)

func main() {
	gin.SetMode("release")
	router := gin.Default()
	router.GET("/", index)

	router.Run()
}

func index(c *gin.Context)  {
	c.String(http.StatusOK, "Welcome to the Simple webapp.")
}
```

Python Code
-----------
```python
from flask import Flask

app = Flask(__name__)


@app.route("/")
def index():
    return "Welcome to the Simple webapp."

if __name__ == "__main__":
    app.run(debug=False)
```


Test Result - Go
----------------
```bash
ab -c 100 -n 5000 http://127.0.0.1:8080/
This is ApacheBench, Version 2.3 <$Revision: 1706008 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 500 requests
Completed 1000 requests
Completed 1500 requests
Completed 2000 requests
Completed 2500 requests
Completed 3000 requests
Completed 3500 requests
Completed 4000 requests
Completed 4500 requests
Completed 5000 requests
Finished 5000 requests


Server Software:        
Server Hostname:        127.0.0.1
Server Port:            8080

Document Path:          /
Document Length:        29 bytes

Concurrency Level:      100
Time taken for tests:   0.697 seconds
Complete requests:      5000
Failed requests:        0
Total transferred:      730000 bytes
HTML transferred:       145000 bytes
Requests per second:    7171.48 [#/sec] (mean)
Time per request:       13.944 [ms] (mean)
Time per request:       0.139 [ms] (mean, across all concurrent requests)
Transfer rate:          1022.50 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        1    6   2.5      5      21
Processing:     2    8   3.7      7      27
Waiting:        1    6   2.8      6      19
Total:          5   14   4.7     13      36

Percentage of the requests served within a certain time (ms)
  50%     13
  66%     15
  75%     17
  80%     18
  90%     20
  95%     22
  98%     27
  99%     30
 100%     36 (longest request)
```

Test Result - Python
--------------------
```bash
ab -c 100 -n 5000 http://127.0.0.1:5000/
This is ApacheBench, Version 2.3 <$Revision: 1706008 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking 127.0.0.1 (be patient)
Completed 500 requests
Completed 1000 requests
Completed 1500 requests
Completed 2000 requests
Completed 2500 requests
Completed 3000 requests
Completed 3500 requests
Completed 4000 requests
Completed 4500 requests
Completed 5000 requests
Finished 5000 requests


Server Software:        Werkzeug/0.10.4
Server Hostname:        127.0.0.1
Server Port:            5000

Document Path:          /
Document Length:        29 bytes

Concurrency Level:      100
Time taken for tests:   4.211 seconds
Complete requests:      5000
Failed requests:        0
Total transferred:      920000 bytes
HTML transferred:       145000 bytes
Requests per second:    1187.49 [#/sec] (mean)
Time per request:       84.211 [ms] (mean)
Time per request:       0.842 [ms] (mean, across all concurrent requests)
Transfer rate:          213.38 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.5      0       5
Processing:     3   83   9.1     81     116
Waiting:        2   83   9.1     81     116
Total:          7   83   9.0     81     117

Percentage of the requests served within a certain time (ms)
  50%     81
  66%     84
  75%     86
  80%     88
  90%     94
  95%     97
  98%    108
  99%    115
 100%    117 (longest request)
```

Difference
----------
```bash
7171.48/1187.49*100 = 603.9191909
```

Go webapps can run over 6 times faster than webapps written in Python.

Memory Consumption
------------------
- Go webapp: 6.3 MB
- Python webapp: 11.9 MB