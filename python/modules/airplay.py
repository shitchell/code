import re
import os
import _io
import time
import uuid
import socket
import requests
import plistlib
import threading
import http.server
import urllib.parse

class AuthenticationError(Exception): pass
class UnsupportedFormatError(Exception): pass
class AirplayDeviceBusyError(Exception): pass

def _is_local(path):
	return not bool(urllib.parse.urlparse(path).scheme) and os.path.exists(path)

def _fetch_data(path):
	if _is_local(path):
		try:
			return open(path, "rb").read()
		except:
			pass
	try:
		return requests.get(path).content
	except:
		pass
	return None

DEBUG = False
def _debug(*msgs, **kwargs):
	global DEBUG
	if not msgs:
		DEBUG = not DEBUG
	elif DEBUG:
		msgs = [str(x).replace("\n", "\\n") for x in msgs]
		print("[%s]" % time.strftime("%c"), *msgs, **kwargs)

# ----------------------------------------------
 # Magic codes for supported file formats

_supported_headers = [
						# Images
						(b'\x89\x50\x4E\x47\x0D\x0A\x1A\x0A', "image/png"), # PNG
						(b'\xFF\xD8\xFF', "image/jpeg"), # JPEG
						(b'\x47\x49\x46\x38', "image/gif"), # GIF
						(b'\x00\x00\x00\x0C\x6A\x50\x20\x20', "image/jp2"), # JPEG-2000
						(b'\x00\x00\x01\x00', "image/x-icon"), # ICO
						(b'\x4D\x4D\x00\x2A', "image/tiff"), # TIFF
						(b'\x49\x49\x2A\x00', "image/tiff"), # TIFF
						(b'\x42\x4D', "image/bmp"), # BMP
						
						# Videos
						(b'\x00\x00\x00\x18\x66\x74\x79\x70\x6D\x70\x34\x32', "video/x-m4v"), # M4V
						(b'\x00\x00\x00.\x66\x74\x79\x70', "video/mp4"), # MP4
						(b'\x33\x67\x70\x35', "video/mp4") # MP4
					]
_supported_trailers = [
						# Images
						(b'TRUEVISION-XFILE.\x00', "image/tga") # TARGA
]

def _get_mime_type(data=None, path=None):
	assert any([data, path]), "Must provide data, a url, or a filepath"
	
	if path and not data:
		data = _fetch_data(path)
	
	if isinstance(data, bytes):
		# Get the longest header and grab only that much of the data
		for header, mimetype in _supported_headers:
			if re.match(header, data[:len(header)]):
				return mimetype
		for trailer, mimetype in _supported_trailers:
			if re.match(trailer, data[-len(trailer):]):
				return mimetype
	return None

def is_compatible(data=None, path=None):
	return bool(_get_mime_type(data, path))

# ----------------------------------------------
 # Handler for GET requests for the video server

class GETHandler(http.server.BaseHTTPRequestHandler):
	def setup(self):
		# Default setup
		self.connection = self.request
		self.rfile = self.connection.makefile("rb", self.rbufsize)
		self.wfile = self.connection.makefile("wb", self.wbufsize)

		# Custom setup
		self._filepath = None
	
	def do_GET(self):
		_debug("Fileserver got request:", self.headers)
		if self.server._filepath and os.path.isfile(self.server._filepath):
			# Get information about the file we're serving
			file = open(self.server._filepath, "rb")
			size = os.stat(file.name).st_size
			
			# Determine what range of bytes we should send, if any
			content_range = None
			status_code = 200
			if "Range" in self.headers:
				p = self.headers["Range"].find("bytes=")
				if p != -1:
					content_range = self.headers["Range"][p + 6:].split("-")
					content_range = [int(x) for x in content_range]
					status_code = 206
			
			# Send the response status code
			self.send_response(status_code)
			self.send_header("Content-Type", "video/mp4")
			
			# Determine the size of the response
			if content_range:
				self.send_header("Content-Range", "bytes %s/%i" % (self.headers.get("Range").replace("bytes=", ""), size))
				response_size = (content_range[1]+1 - content_range[0])
			else:
				response_size = size
			self.send_header("Content-Length", response_size)
			self.end_headers()
			
			# Send the requested data
			if content_range:
				file.seek(content_range[0])
				data_len = content_range[1]+1 - content_range[0]
				data = file.read(data_len)
				try:
					self.wfile.write(data)
				except Exception as e:
					return
			else:
				try:
					self.wfile.write(file.read())
				except Exception as e:
					return
		else:
			self.send_response(404)
			self.end_headers()

	def log_message(self, format, *args):
		return

class FileServer(http.server.HTTPServer):
	def __init__(self, server_address, RequestHandlerClass, bind_and_activate=True):
		http.server.HTTPServer.__init__(self, server_address, RequestHandlerClass, bind_and_activate=True)
		self._thread = None
		self._filepath = None
	
	def server_bind(self):
		# Make sure that we bind to an open port
		addr, port = self.server_address
		while True:
			try:
				self.socket.bind((addr, port))
			except:
				port += 1
			else:
				break
		self.server_address = self.socket.getsockname()
		host, port = self.socket.getsockname()[:2]
		self.server_name = socket.getfqdn(host)
		self.server_port = port
	
	def serve(self, filepath=None):
		if not self._thread:
			self._thread = threading.Thread(target=self.serve_forever, args=[])
			self._thread.daemon = True
			self._thread.start()
		if filepath:
			self._filepath = filepath
	
	def stop(self):
		self._thread.stop()
		self._thread = None
		self._filepath = None

# ----------------------------------------------
 # Class to interface with an airplay device

class AirplayServer:
	def __init__(self, hostname="Apple-TV", password=None, port=7000):
		self.hostname = hostname
		self.port = port
		
		# Create a session with the server
		self._session = requests.Session()
		self._session.trust_env = False # trust nothing >:O
		if password:
			self.set_password(password)
		self._session.headers["X-Apple-Session-ID"] = str(uuid.uuid1())
		
		# Set up the photo cache
		self._photo_cache = dict()
				
		# Set up our file server
		self._fileserver = FileServer(("", 8000), GETHandler)
		
		# Random stuffs
		self._min_step = .0011
		self._keeping_alive = False
		self._slideshow_features = {}
	
	# --------------------------
	 # Authentication stuffs
	
	def set_hostname(self, hostname):
		self.hostname = hostname
	
	def set_password(self, password):
		self._session.auth = requests.auth.HTTPDigestAuth("AirPlay", password)
	
	# --------------------------
	 # Media playback defs
	
	def play(self, path=None, position=0, force=True):
		if self.is_playing_movie() and not force:
			raise AirplayDeviceBusyError("Movie playing. Try using the 'force' option to force media playback.")
		
		if not path:
			self._rate(1)
			return
		if _is_local(path):
			self._fileserver.serve(path)
			url = "http://%s:%s/video.mp4" % (socket.gethostbyname(socket.gethostname()), self._fileserver.server_port)
		elif urllib.parse.urlparse(path).scheme:
			url = path
		else:
			return False
		res = self._req("POST", "play", "Content-Location: %s\nStart-Position: %i\n" % (url, position))
		if res.ok:
			self._keep_alive()
			return True
		return False
	
	def pause(self):
		self._rate(0)
	
	def unpause(self):
		self._rate(1)
	
	def toggle_pause(self):
		self._rate(int(not self.is_paused()))
	
	def stop(self):
		self._req("POST", "stop")
	
	def fast_forward(self):
		self._rate(10)
	
	def rewind(self):
		self._rate(-5)
	
	def step(self, steps=1, size=.033):
		self.pause()
		value = steps * size
		if abs(value) < self._min_step:
			sign = value / abs(value)
			value = sign * self._min_step
		self.seek(self.position + value)
	
	def seek(self, position):
		self._req("POST", "scrub?position=%f" % position)
	
	# --------------------------
	 # Photo defs
	
	def photo(self, path, transition="None", cache=True):
		# Always use an absolute path for local files
		if _is_local(path):
			path = os.path.abspath(path)
		# Try to find the path in the cache, first
		cid = self._photo_cache.get(path)
		if cid:
			response = self._req("PUT", "photo", headers={"X-Apple-Transition": transition, "X-Apple-AssetAction": "displayCached", "X-Apple-AssetKey": cid})
			if response.ok:
				return True
		# There was no cache or the Apple TV's cache has expired
		# Start by fetching the image data from a local or external source
		data = _fetch_data(path)
		if data:
			if cache:
				# Cache the photo
				cid = self._cache_photo(path, data)
				# Then display it
				response = self._req("PUT", "photo", headers={"X-Apple-Transition": transition, "X-Apple-AssetAction": "displayCached", "X-Apple-AssetKey": cid})
				if response.ok:
					return True
			# Either the cache failed or we shouldn't cache it, so attempt to just PUT the image data
			return self._req("PUT", "photo", data, headers={"X-Apple-Transition": transition}).ok
		return False
	
	def cache(self, path):
		if _is_local(path):
			path = os.path.abspath(path)
		data = _fetch_data(path)
		if data:
			return self._cache_photo(path, data)
		return None
	
	def _cache_photo(self, path, data):
		cid = str(uuid.uuid1()).upper()
		res = self._req("PUT", "photo", data, headers={"X-Apple-AssetAction": "cacheOnly", "X-Apple-AssetKey": cid})
		if res.ok:
			self._photo_cache[path] = cid
			return cid
	
	# --------------------------
	 # Slideshow stuffs
	
	def slideshow(self, func=None, filepaths=[], datas=[]):
		assert sum([bool(func), bool(filepaths), bool(datas)]) == 1, "Must provide one function, list of filepaths, or list of image data"
	
	@property
	def slideshow_features(self):
		if not self._slideshow_features:
			info = self._req("GET", "slideshow-features").content
			self._slideshow_features = plistlib.readPlistFromBytes(info)
		return self._slideshow_features
	
	# --------------------------
	 # Current state info
	
	def is_paused(self):
		return bool(not self.rate)
	
	def is_playing_movie(self):
		return "duration" in self.playback_info
	
	@property
	def rate(self):
		return self.playback_info.get("rate")
	
	@rate.setter
	def rate(self, x):
		return self._rate(x)
	
	@property
	def duration(self):
		return self.playback_info.get("duration")
	
	@property
	def position(self):
		return self.playback_info.get("position")
	
	@position.setter
	def position(self, x):
		return self.seek(x)
	
	@property
	def playback_info(self):
		info = self._req("GET", "playback-info").content
		return plistlib.readPlistFromBytes(info)
	
	# --------------------------
	 # Helpful defs
	
	def _rate(self, value):
		self._req("POST", "rate?value=%f" % value)
	
	def _keep_alive(self):
		if not self._keeping_alive:
			# Don't have more than 1 of this thread running at a time
			self._keeping_alive = True
			# Function to poll while the movie is playing
			def poll_forever():
				# Give the movie a little time to load first
				time.sleep(8)
				info = self.playback_info
				reason = "movie died a natural death"
				while "readyToPlay" in info:
					info = self.playback_info
					position = info.get("position")
					duration = info.get("duration")
					# Once we get to the end of the movie, we have to manually stop it
					if info.get("position", 0) - info.get("duration", 1) > -1 and info.get("rate", 0) == 0:
						reason = "reached end of movie and forced a stop: %r" % info
						self.stop()
						break
					# Poll every second
					time.sleep(1)
				_debug(reason, info)
				self._keeping_alive = False
			t = threading.Thread(target=poll_forever)
			t.daemon = True
			t.start()
	
	def _req(self, method, url, data="", headers={}):
		_debug("SENDING [%s] REQUEST:" % method, url, data)
		url = "http://%s:%i/%s" % (self.hostname, self.port, url)
		res = self._session.request(method, url, data=data, headers=headers)
		if res.status_code == 401:
			raise AuthenticationError
		return res

# ----------------------------------------------
 # Class to interface with an Airtunes device

class AirtunesServer:
	def __init__(self, hostname, port):
		self.hostname = hostname