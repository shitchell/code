#!/usr/bin/env python3

from importlib.machinery import SourceFileLoader
import readline
import glob
import http.server
import socketserver
import urllib
import glob
import random
import time
import sys

if len(sys.argv) > 1:
	port = int(sys.argv[1])
else:
	port = 9000

NOLOG = False
def print(msg, *args, **kwargs):
	if not NOLOG:
		timestamp = time.strftime('[%Y-%M-%d %H:%M.%S]')
		args = ' '.join(list(map(lambda x: str(x), args)))
		sys.stdout.write('%s %s %s\n' % (timestamp, str(msg), args))
		sys.stdout.flush()

class Commands:
	modules = dict()
	
	def _find_action(action):
		# See if the action is attached to a particular module
		if action.count(".") == 1:
			module, action = action.split(".")
			module = Commands.modules.get(module)
			if module:
				try:
					func = getattr(module, "do_" + action)
				except:
					pass
				else:
					return func
		else:
			try:
				# Search the default commands
				func = getattr(Commands, "do_" + action)
			except:
				pass
			else:
				return func
	
	def _list_actions():
		if Commands._action_cache:
			return Commands._action_cache
		
		# Loop through the default and external commands
		actions = list()
		modules = [Commands] + list(Commands.modules.values())
		for module in modules:
			mod_actions = filter(lambda x: x.startswith("do_"), dir(module))
			# Filter hidden commands
			mod_actions = filter(lambda x: not getattr(getattr(module, x), "hidden", False), mod_actions)
			if module.__name__ == "Commands":
				mod_actions = map(lambda x: x[3:], mod_actions)
			else:
				## prepend the command with the module name
				mod_actions = map(lambda x: "%s.%s" % (module.__name__, x[3:]), mod_actions)
			actions.extend(list(mod_actions))
		
		# Store the list of commands for efficiency's sake
		Commands._action_cache = actions
		return actions
	
	def _load_base_template(filepath='base.html'):
		f = open(filepath, 'r')
		Commands._base_template = f.read()
		f.close()
	
	def _page_template(title, content, subtitle=""):
		if not Commands._base_template:
			# Load the base template
			Commands._load_base_template()
		
		# Substitute stuffs out
		base = Commands._base_template % {"title": title, "subtitle": subtitle, "content": content}
		return bytes(base, "UTF-8")
	
	def _help_template(func):
		action = func.__name__[3:]
		# Parse samples
		sample = ''
		if hasattr(func, "samples"):
			sample = '<span class="sample">' + '</span><span class="sample">'.join(func.samples) + '</span>'
		return Commands._page_template(action, func.__doc__ or "No documentation", sample)
	
	def do_help(req, *args, **kwargs):
		"""Provides documentation on commands"""
		if args:
			func = Commands._find_action(args[0])
			if func:
				req.wfile.write(Commands._help_template(func))
				return
		# Create links for each command
		action_links = map(lambda x: '<a href="/help/%s">%s</a><br />' % (x, x), Commands._list_actions())
		action_links = "\n".join(list(action_links))
		help = Commands._page_template("Commands", action_links)
		req.wfile.write(help)
	do_help.samples = ["/help/reload", "/help/foo.bar"]
	def do_reload(req, *args, **kwargs):
		"""Refreshes external modules"""
		load_modules()
		req.wfile.write(bytes('<meta http-equiv="refresh" content="0;URL=/">', "UTF-8"))
	
def load_modules():
	# Dump old modules
	Commands.modules = dict()
	# Dump old command cache
	Commands._action_cache = list()
	# Reload base template
	Commands._load_base_template()
	# Load external command modules
	for path in glob.glob('rpi_*.py'):
		# load the individual module
		name = path.split('.')[0][4:]
		try:
			module = SourceFileLoader(name, path).load_module()
			# Change the format for module output
			module.__builtins__["print"] = print
		except Exception as e:
			print("! Error loading module '%s': %s" % (name, e))
		else:
			Commands.modules[name] = module
			print("loaded module '%s'" % name)
load_modules()

class Server(http.server.SimpleHTTPRequestHandler):
	def do_GET(self):
		# Send initial headers
		self.protocol_version='HTTP/1.1'
		self.send_response(200, 'OK')
		self.send_header('Content-type', 'text/html')
		self.end_headers()

		# Get the kwargs
		path = self.path.split('?')
		kwargs = dict()
		if len(path) > 1:
			for kwarg in path[1].split('&'):
				kw, arg = kwarg.split('=')
				kwargs[kw] = urllib.parse.unquote(arg)
		
		# Get the action and args
		path = self.path.split('?')[0]
		path = path.rstrip('/').split('/')[1:]
		if path:
			action = path.pop(0)
			args = list(map(lambda x: urllib.parse.unquote(x), path))
		else:
			action = None
			args = None
		
		# Find the command to execute
		if action:
			print("(action) %s (args) %s (kwargs) %s" % (action, args, kwargs))
			
			func = Commands._find_action(action)
			if func:
				try:
					func(self, *args, **kwargs)
				except Exception as e:
					print("! Error executing function '%s'" % action)
					print("!!", e)
				return
		Commands.do_help(self)
	
	def log_message(self, format, *args):
		pass

if __name__ == "__main__":
	while True:
		try:
			server = socketserver.TCPServer(('', port), Server)
			print("Serving on port %i" % port)
			server.serve_forever()
		except KeyboardInterrupt:
			NOLOG = True
			print("^C one more time to exit")
			while True:
				try:
					x = input("> ")
				except EOFError:
					break
				except KeyboardInterrupt:
					server.socket.close()
					sys.exit(1)
				
				try:
					exec(x)
				except Exception as e:
					print(e)
			NOLOG = False
