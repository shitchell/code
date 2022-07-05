from . import colors
import time
import inspect

LOGLEVEL = 0

def enable():
	_enabled = True

def disable():
	_enabled = False

def log(*args, timestamp=False, level=1, tb=False):
	# Don't do shit if not enabled
	if not _enabled:
		return
	# Ensure that the correct log level is matched
	if LOGLEVEL != 0 or level < LOGLEVEL:
		return
	
	# Join all args with a space
	line = " ".join([repr(x) for x in args])
	if timestamp == True:
		strftime = "%F %H:%M.%S"
	elif type(timestamp) == str:
		stfrtime = timestamp
	if timestamp:
		line = colors.fg.blue + time.strftime(strftime) + colors.reset + " " + line
	print(line)

inspect.getouterframes( inspect.currentframe() )