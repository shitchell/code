import sys
import subprocess

# Make sure that omxplayer is installed
cmd = subprocess.Popen(["which", "omxplayer"], stdout=subprocess.PIPE)
if not cmd.stdout.read():
	raise Exception("This module requires 'omxplayer' to be installed")


