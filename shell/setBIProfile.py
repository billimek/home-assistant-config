#!/usr/local/bin/python3
####
## Script to set a specific profile in Blue Iris

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
    secrets = yaml.load(sf)

bi_server = secrets["bi_server"]
bi_user = secrets["bi_user"]
bi_pass = secrets["bi_pass"]

#log cleanup
path = r"{}/shell".format(configdir)
now = time.time()
for f in os.listdir(path):
	f = os.path.join(path, f)
	#print(f)
	#print(os.path.splitext(f)[1])
	if os.path.splitext(f)[1] == ".log":
		#print(f)
		#print(os.stat(f).st_mtime)
		if os.stat(f).st_mtime < now - 2 * 86400:
			#print(f)
			if os.path.isfile(f):
				os.remove(f)

now = datetime.strftime(datetime.now(), '%Y%m%d_%H%M')
logNow = datetime.strftime(datetime.now(), '%Y%m%d_%H%M%S')

logger = logging.getLogger('setBIProfile')
logger.setLevel(logging.INFO)

handler = logging.FileHandler('{}/shell/setBIProfile_{}_{}.log'.format(configdir,sys.argv[1],logNow))
handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

if sys.argv[1] == "home":
	prof = 1
	enabled = False
elif sys.argv[1] == "away":
	prof = 2
	enabled = True
elif sys.argv[1] == "alert_night":
	prof = 3
	enabled = False
elif sys.argv[1] == "day":
    prof = 4
    enabled = True
elif sys.argv[1] == "day_windy":
    prof = 5
    enabled = True
elif sys.argv[1] == "night":
    prof = 6
    enabled = True
elif sys.argv[1] == "tensorflow":
    prof = 7
    enabled = True
else:
	quit

logger.info('Running script to set profile to {}'.format(sys.argv[1]))
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
		if r.json()['result'] == 'success':
			if r.json()['data']['profile'] != prof:
				#profile is not what we think it should be... set it
				logger.info('Switching profile')
				data = {'cmd':'status','session':session,'profile':prof}
				r = requests.post(url,json.dumps(data))
				if r.json()['result'] == 'success':
					#successfully changed profile
					logger.info('Success')
					# logger.info('Sending notification to slack')
					# surl = secrets["slack_notification_webhook"]
					# stext = "profile set to '{}'".format(sys.argv[1])
					# slack_icons_location = secrets["slack_icons_location"]
					# iconurl = "{}/HAfavicon.ico".format(slack_icons_location)
					# payload = {'channel':'#notifications','text':stext,'username':'BlueIris','icon_url':iconurl}
					# req = requests.post(surl, json.dumps(payload), headers={'content-type': 'application/json'})
					# #disable/enable cams in BI based on home/away profile
					# cams = "jackcam","ryancam"
					# for cam in cams:
					# 	logger.info('Setting {} to enabled:{}'.format(cam,enabled))
					# 	data = {'camera':cam,'enable':enabled,'session':session,'cmd':'camconfig'}
					# 	print(data)
					# 	r = requests.post(url,json.dumps(data))
			else:
				logger.info('BI profile is already set')
	logger.info('Logging out')
	url = "http://{}:81/json".format(bi_server)
	data = {'cmd':'logout','session':session}
	r = requests.post(url,json.dumps(data))
	logger.info('result: {}'.format(r.json()['result']))
	logger.info('Done')
