import imaplib
import smtplib
import email.utils
import email.encoders
import email.mime.text
import email.mime.base
import email.mime.multipart

def login(username, password):
	return Account(username, password)

class InvalidCredentials(Exception): pass

class Account:
	def __init__(self, username, password):
		self.username = username
		self.password = password
		self._login()
	
	def _login(self):
		self.imap = IMAP(self)
		self.smtp = SMTP(self)
	
	def get_unread(self):
		next = self.imap.next()
		

class IMAP:
	def __init__(self, account):
		self.account = account
		self._unread = []
		self.login()
	
	def _login(self):
		# Connect and authenticate
		self.conn = imaplib.imaplib.IMAP4_SSL('imap.gmail.com')
		self.conn.login(self.account.username.encode(), self.account.password.encode())
		# All transactions require this "tag" given to us on login
		self.tag = "%s%i" % (self.conn.tagpre.decode(), self.conn.tagnum)
		# Select the main inbox
		self.conn.select()
		# Get unread messages
		self._unread = self.conn.search(None, '(UNSEEN)')[1][0].split()
		# Set the idling status
		self._idling = False
		# Set up a socket timeout to prevent google from hating us off their server
		IMAP.imap.sock.settimeout(180)
	
	def _fetch(mid):
		pass
	
	def next(self):
		pass

class SMTP:
	def __init__(self, account):
		self.account = account
		self.login()
	
	def _login(self):
		pass