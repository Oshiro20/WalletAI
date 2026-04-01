import urllib.request
import urllib.error
import json

url = 'https://api-gastos-6iri.onrender.com/api/parse-voice'
data = json.dumps({'systemPrompt':'Eres un bot', 'userMessage':'hola'}).encode('utf-8')
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})

try:
    response = urllib.request.urlopen(req)
    print("SUCCESS: ", response.read().decode())
except urllib.error.HTTPError as e:
    print("HTTP ERROR:", e.code)
    print("BODY:", e.read().decode())
except Exception as e:
    print("ERROR:", str(e))
