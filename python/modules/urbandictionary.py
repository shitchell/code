import re
import json
import urllib.parse
import urllib.request

def lookup(word):
	while 1:
		try:
			res	= json.loads(urllib.request.urlopen('http://www.urbandictionary.com/iphone/search/define?term=' + urllib.parse.quote(word)).read().decode())
		except:
			continue
		else:
			break
	if res.get('result_type') == 'exact':
		results	= res['list']
		definition	= results[0].get('definition')
		definition	= definition.replace('<br/>', '\n')
		return definition.replace('\r\n', '\n')
