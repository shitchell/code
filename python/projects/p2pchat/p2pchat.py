#!/usr/bin/env python3.1

import uuid
import time
import curses
import socket
import random
import hashlib
import optparse
from getpass import getpass
from blowfish import Blowfish

parser = optparse.OptionParser()
parser.add_option("-p", "--port", dest="port", type="int", default=1337, help="The port the server should bind to.")
(options, optionargs) = parser.parse_args()

HOSTS = dict()
CIPHER = Blowfish(getpass('Key: ')[:56])
PACKET_MAX = 1450
STRUCT_FORMAT = '>I'
NAMES = {
			'first': ['James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Charles', 'Joseph', 'Thomas', 'Christopher', 'Daniel', 'Paul', 'Mark', 'Donald', 'George', 'Kenneth', 'Steven', 'Edward', 'Brian', 'Ronald', 'Anthony', 'Kevin', 'Jason', 'Matthew', 'Gary', 'Timothy', 'Jose', 'Larry', 'Jeffrey', 'Frank', 'Scott', 'Eric', 'Stephen', 'Andrew', 'Raymond', 'Gregory', 'Joshua', 'Jerry', 'Dennis', 'Walter', 'Patrick', 'Peter', 'Harold', 'Douglas', 'Henry', 'Carl', 'Arthur', 'Ryan', 'Roger', 'Joe', 'Juan', 'Jack', 'Albert', 'Jonathan', 'Justin', 'Terry', 'Gerald', 'Keith', 'Samuel', 'Willie', 'Ralph', 'Lawrence', 'Nicholas', 'Roy', 'Benjamin', 'Bruce', 'Brandon', 'Adam', 'Harry', 'Fred', 'Wayne', 'Billy', 'Steve', 'Louis', 'Jeremy', 'Aaron', 'Randy', 'Howard', 'Eugene', 'Carlos', 'Russell', 'Bobby', 'Victor', 'Martin', 'Ernest', 'Phillip', 'Todd', 'Jesse', 'Craig', 'Alan', 'Shawn', 'Clarence', 'Sean', 'Philip', 'Chris', 'Johnny', 'Earl', 'Jimmy', 'Antonio', 'Mary', 'Patricia', 'Linda', 'Barbara', 'Elizabeth', 'Jennifer', 'Maria', 'Susan', 'Margaret', 'Dorothy', 'Lisa', 'Nancy', 'Karen', 'Betty', 'Helen', 'Sandra', 'Donna', 'Carol', 'Ruth', 'Sharon', 'Michelle', 'Laura', 'Sarah', 'Kimberly', 'Deborah', 'Jessica', 'Shirley', 'Cynthia', 'Angela', 'Melissa', 'Brenda', 'Amy', 'Anna', 'Rebecca', 'Virginia', 'Kathleen', 'Pamela', 'Martha', 'Debra', 'Amanda', 'Stephanie', 'Carolyn', 'Christine', 'Marie', 'Janet', 'Catherine', 'Frances', 'Ann', 'Joyce', 'Diane', 'Alice', 'Julie', 'Heather', 'Teresa', 'Doris', 'Gloria', 'Evelyn', 'Jean', 'Cheryl', 'Mildred', 'Katherine', 'Joan', 'Ashley', 'Judith', 'Rose', 'Janice', 'Kelly', 'Nicole', 'Judy', 'Christina', 'Kathy', 'Theresa', 'Beverly', 'Denise', 'Tammy', 'Irene', 'Jane', 'Lori', 'Rachel', 'Marilyn', 'Andrea', 'Kathryn', 'Louise', 'Sara', 'Anne', 'Jacqueline', 'Wanda', 'Bonnie', 'Julia', 'Ruby', 'Lois', 'Tina', 'Phyllis', 'Norma', 'Paula', 'Diana', 'Annie', 'Lillian', 'Emily', 'Robin'],
			'last': ['Smith', 'Johnson', 'Williams', 'Jones', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor', 'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Thompson', 'Garcia', 'Bond', 'Robinson', 'Clark', 'Rodriguez', 'Davidson', 'Lee', 'Walker', 'Hall', 'Allen', 'Young', 'Hernandez', 'King', 'Wright', 'Lopez', 'Hill', 'Scott', 'Green', 'Adams', 'Baker', 'Gonzalez', 'Nelson', 'Carter', 'Mitchell', 'Perez', 'Roberts', 'Turner', 'Phillips', 'Campbell', 'Parker', 'Evans', 'Edwards', 'Collins', 'Stewart', 'Sanchez', 'Morris', 'Rogers', 'Reed', 'Cook', 'Morgan', 'Bell', 'Murphy', 'Bailey', 'Rivera', 'Cooper', 'Richardson', 'Cox', 'Howard', 'Ward', 'Torres', 'Peterson', 'Gray', 'Ramirez', 'James', 'Watson', 'Brooks', 'Kelly', 'Sanders', 'Price', 'Bennett', 'Wood', 'Barnes', 'Ross', 'Henderson', 'Coleman', 'Jenkins', 'Perry', 'Powell', 'Long', 'Patterson', 'Hughes', 'Flores', 'Washington', 'Butler', 'Simmons', 'Foster', 'Gonzales', 'Bryant', 'Alexander', 'Russell', 'Griffin', 'Diaz', 'Hayes', 'Myers', 'Ford', 'Hamilton', 'Graham', 'Sullivan', 'Wallace', 'Woods', 'Cole', 'West', 'Jordan', 'Owens', 'Reynolds', 'Fisher', 'Ellis', 'Harrison', 'Gibson', 'Mcdonald', 'Cruz', 'Marshall', 'Ortiz', 'Gomez', 'Murray', 'Freeman', 'Wells', 'Webb', 'Simpson', 'Stevens', 'Tucker', 'Porter', 'Hunter', 'Hicks', 'Crawford', 'Henry', 'Boyd', 'Mason', 'Morales', 'Kennedy', 'Warren', 'Dixon', 'Ramos', 'Reyes', 'Burns', 'Gordon', 'Shaw', 'Holmes', 'Rice', 'Robertson', 'Hunt', 'Black', 'Daniels', 'Palmer', 'Mills', 'Nichols', 'Grant', 'Knight', 'Ferguson', 'Rose', 'Stone', 'Hawkins', 'Dunn', 'Perkins', 'Hudson', 'Spencer', 'Gardner', 'Stephens', 'Payne', 'Pierce', 'Berry', 'Matthews', 'Arnold', 'Wagner', 'Willis', 'Ray', 'Watkins', 'Olson', 'Carroll', 'Duncan', 'Snyder', 'Hart', 'Cunningham', 'Bradley', 'Lane', 'Andrews', 'Ruiz', 'Harper', 'Fox', 'Riley', 'Armstrong', 'Carpenter', 'Weaver', 'Greene', 'Lawrence', 'Elliott', 'Chavez', 'Sims', 'Austin', 'Peters', 'Kelley', 'Franklin', 'Lawson']
			}

class User:
	def __init__(self):
		self.keyhash = None
		self.name = None
		self.uid = None
		self.ip = None
		self.last_ping = None
	
	def __eq__(self, y):
		if self.uid == y:
			return True
		return False
	
	def update(self, data):
		if isinstance(data, bytes):
			data = data.decode()
		data = str(data)
		match = re.match('([a-fA-F\d]{32})([a-fA-F\d]{32})(.*)', data)
		if match:
			uid, keyhash, info = match.groups()
			info = decrypt(info)
			match = re.match('(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(.*)', info)
			if match:
				ip, name = match.groups()
				self.keyhash = keyhash
				self.name = name
				self.uid = uid
				self.ip = ip
				self.last_ping = time.time()			
	
	def __repr__(self):
		return "%s%s%s" % (self.uid, self.keyhash, encrypt(self.ip + ":" + self.name))

def encrypt(text):
	# Allow any format to be passed in as an argument
	if isinstance(text, bytes):
		text = text.decode()
	text = str(text)
	# Determine how much padding should be applied to our text to satisfy our block size
	p = CIPHER.blocksize() - (len(text) % CIPHER.blocksize())
	text = text + (str(p) * p)
	# Split the text into blocks and encrypt each
	encrypted = ""
	for i in range(0, len(text), CIPHER.blocksize()):
		block = text[i:i+CIPHER.blocksize()]
		encrypted += CIPHER.encrypt(block)
	return encrypted

def decrypt(text):
	# Split the text into blocks and decrypt each
	decrypted = ""
	for i in range(0, len(text), CIPHER.blocksize()):
		block = text[i:i+CIPHER.blocksize()]
		if len(block) != CIPHER.blocksize():
			return None
		decrypted += CIPHER.decrypt(block)
	# Remove any padding
	try:
		p = int(decrypted[-1])
	except:
		return None
	else:
		return decrypted[:-p]

def broadcast():
	while 1:
		say("")
		time.sleep(5)

def remove_online():
	while 1:
		for host in HOSTS:
			if time.time() - HOSTS[host].last_ping > 7:
				del HOSTS[host]
		time.sleep(1)

def recv():
	while 1:
		(message, (ip, port)) = s.recvfrom(options.port)
		if message:
			flag = message[0]
			message = message[1:]
			if flag == b'\x01':
				# Receive a message
				h = message[:4]
			elif flag == b'\x00':
				# Receive a broadcast
				pass
			if match:
				uid, keyhash, name = match.groups()
				if keyhash == KEYHASH and uid != SESSION:
					HOSTS[session] = User

def recv():
	while 1:
		(message, (ip, port)) = s.recvfrom(options.port)
		if message:
			# Try to break the message up into chunks
			i = 0
			chunks = []
			validated = True
			s_len = struct.calcsize(STRUCT_FORMAT)
			while i < len(message):
				s = message[i:i+s_len]
				try:
					chunk_size = struct.unpack(s)
				except:
					validated = False
					break
				i = i + s_len
				chunk = message[i:i+chunk_size]
				chunks.append(chunk)
				i = i + chunk_size
			if validated:
				# Handle the chunks
				u = User().update(chunks[0])
				for chunk in chunks[1:]:
					pass

def send(**kwargs):
	# Structify the session info
	s_info = "%r" % session
	s_info = struct.pack(STRUCT_FORMAT, len(s_info)) + s_info.encode()
	# Because of UDP packet size limits, send 1 packet per kwarg
	for key in kwargs:
		if key == "broadcast":
			line = ""
		else:
			if isinstance(kwargs[key], bytes):
				kwargs[key] = kwargs[key].decode()
			line = "%s:%r" % (key, kwargs[key])
			line = encrypt(line)
			line = struct.pack(STRUCT_FORMAT, len(line))
		s.sendto(s_info + line.encode(), ('255.255.255.255', options.port))

# Set up the current user information
session = User()
session.keyhash = hashlib.md5(str(CIPHER.p_boxes + CIPHER.s_boxes).encode()).hexdigest()
session.name = random.choice(NAMES['first']) + " " + random.choice(NAMES['last'])
session.uid = uuid.uuid1().hex
session.ip = socket.gethostbyname(socket.gethostname())

# Set up our client/server socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', options.port))

