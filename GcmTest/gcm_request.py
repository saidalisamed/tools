import concurrent.futures
import requests

GCM_API_KEY = 'API_KEY_HERE'
TOKEN = 'REGISTRATION_TOKEN_HERE'

url = 'https://gcm-http.googleapis.com/gcm/send'
headers = {
    'Content-Type': 'application/json',
    'Authorization': 'key=' + GCM_API_KEY
}
payload = {
    'to': TOKEN,
    'priority': 'normal',
    'data': {
        'title':'Test Message',
        'message': 'This is a test message to demonstrate how to POST json to GCM using Python Requests library.'
    }
}


def send_notification(**kwargs):
    session = kwargs['session']
    r = session.post(url, headers=kwargs['headers'], json=kwargs['payload'])
    print(r.text)


endpoints = []
for i in range(100):
    endpoints.append(TOKEN)

e = concurrent.futures.ThreadPoolExecutor(max_workers=25)
s = requests.Session()
for endpoint in endpoints:
    e.submit(send_notification, session=s, headers=headers, payload=payload)
e.shutdown()
