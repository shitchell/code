from functools import wraps
import discovery
import requests
import random

playlist_path = "youtube.txt"
chromecast = None

# Decorator to require a chromecast on the network
def require_chromecast(func):
	@wraps(func)
	def func_wrapper(req, *args, **kwargs):
		global chromecast
		
		# Try to find any chromecasts on the network if the exist
		print("Chromecast: %s" % chromecast)
		if not chromecast:
			print("Discovering chromecasts")
			discover_chromecasts()
		
		# Make sure we found / have a chromecast
		if chromecast:
			resp = requests.get('http://' + chromecast + ':8008/ssdp/device-desc.xml')
			print("'chromecast' in response: %s" % 'chromecast' in resp.text)
			# Try to make sure that it's a chromecast
			if 'chromecast' in resp.text:
				return func(req, *args, **kwargs)
			else:
				# What we found isn't a chromecast
				chromecast = None
		
		# No chromecast found
		print('! No chromecast on network')
	return func_wrapper

def get_videos():
	global playlist_path
	
	# Load video information from a file
	# file follows the format 'Artist\tSong\tYoutube ID\tTags'
	f = open(playlist_path)
	data = f.read()
	f.close()
	
	# Parse the video information
	videos = dict()
	data = data.split('\n')
	for datum in data:
		line = datum.split("#")[0]
		if line:
			fields = line.split('\t')
			if len(fields) == 4:
				artist, song, vid, tags = fields
				tags = tags.split(',')
				videos[vid] = {"artist": artist, "title": song, "tags": tags}
	return videos

@require_chromecast
def stream_url(url):
	if url.count("="):
		vid = url.split('v=', 1)[1].split('&', 1)[0]
	else:
		vid = url
	requests.post('http://' + chromecast + ':8008/apps/YouTube', {'v': vid})

@require_chromecast
def do_stop(req, *args, **kwargs):
	'''Stop YouTube playback'''
	global chromecast
	requests.delete('http://' + chromecast + ':8008/apps/YouTube')

@require_chromecast
def do_reboot(req, *args, **kwargs):
	'''Reboot the local chromecast dongle'''
	global chromecast
	requests.post('http://' + chromecast + ':8008/setup/reboot', json={'params': 'now'})

def do_random(req, *args, **kwargs):
	'''Cast a random Youtube Video from a local playlist'''
	global playlist_path
	
	if args:
		subaction = args[0]
		# Go through the available actions
		if subaction == "list":
			f = open(playlist_path, 'r')
			data = f.read()
			f.close()
			req.wfile.write(bytes("<pre>%s</pre>" % data, "UTF-8"))
	else:
		vid = random.choice(list(get_videos().keys()))
		stream_url(vid)
	
do_random.samples = [
	"/cast.random",
	"/cast.random/list",
#	"/cast.random?tag=acoustic",
#	"/cast.random?band=Imagine%20Dragons"
]
			
def do_video(req, *args, **kwargs):
	'''Cast a specific YouTube video'''
	
	if args:
		vid = args[0]
		stream_url(vid)
	return True
do_video.samples = ["/cast.video/M4zCOHFrLVY"]

# Find local chromecasts
def discover_chromecasts():
	global chromecast
	
	chromecasts = discovery.discover_chromecasts()
	if chromecasts:
		chromecast = chromecasts[0][0]
		print("found chromecast '%s'" % chromecast)
	else:
		chromecast = None
discover_chromecasts()
