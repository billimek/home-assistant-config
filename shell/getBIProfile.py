####
## script to query the currently set profile in Blue Iris. This script is used by a command line sensor

import json
import requests
import hashlib
import sys
from datetime import datetime
import logging
import time
import os
import yaml

configdir = "/config"
#configdir = "x:\\hass-config"

with open('{}/secrets.yaml'.format(configdir), 'r') as sf:
    secrets = yaml.safe_load(sf)

bi_server = secrets["bi_server"]
bi_user = secrets["bi_user"]
bi_pass = secrets["bi_pass"]

url = "http://{}:81/json".format(bi_server)
data = {'cmd':'login'}
r = requests.post(url,json.dumps(data))

session = r.json()['session']
if session != "":
	str = "{0}:{1}:{2}".format(bi_user,session,bi_pass)
	m = hashlib.md5()
	m.update(str.encode('utf-8'))
	hash = m.hexdigest()
	data = {'cmd':'login','session':session,'response':hash}
	r = requests.post(url,json.dumps(data))

	if r.json()['result'] == 'success':
		data = {'cmd':'status','session':session}
		r = requests.post(url,json.dumps(data))
		#print("profile is: \'", r.json()['data']['profile'], "\'\n")
		#profiles_list = r.json()["data"]["profile"]
		#profile_id = int(r["profile"])
		#print("new profile is: \'", profiles_list, "\'")
		if r.json()['result'] == 'success':
			if r.json()['data']['profile'] == 1:
				print("home")
			elif r.json()['data']['profile'] == 2:
				print("away")
			elif r.json()['data']['profile'] == 3:
				print("alert_night")
			elif r.json()['data']['profile'] == 4:
				print("day")
			elif r.json()['data']['profile'] == 5:
				print("day_windy")
			elif r.json()['data']['profile'] == 6:
				print("night")
			elif r.json()['data']['profile'] == 7:
				print("tensorflow")
			else:
				print("unknown")
				#print(r.json()['data']['profile'])
