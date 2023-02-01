import enum
import json
from typing import Dict

import discord

class DiscordEvent(enum.Enum):
    MESSAGE = 'message'
    MENTION = 'mention'
    USER_STATUS = 'user_status'
    USER_TYPING = 'user_typing'

# Create a new client object
intents = discord.Intents.all()
client = discord.Client(intents=intents)

# function to log event and data
def log_event(event: DiscordEvent, data: Dict):
    print(f'Event: {event.value}, Data: {json.dumps(data)}')

# Use the on_ready() event to know when the bot is connected and authenticated
@client.event
async def on_ready():
    log_event(DiscordEvent.USER_STATUS, {'status': 'authenticated'})

# Use the on_message() event to listen for new messages
@client.event
async def on_message(message):
    log_event(DiscordEvent.MESSAGE, {'content': message.content})

# Use the on_member_update() event to listen for user status message changes
@client.event
async def on_member_update(before, after):
    if before.status != after.status:
        log_event(DiscordEvent.USER_STATUS, {'username': after.name, 'before': before.status, 'after': after.status})

# Use the on_mention() event to listen for new mentions
@client.event
async def on_message(message):
    if message.mention_everyone or message.mentions:
        log_event(DiscordEvent.MENTION, {'content': message.content})

# Listen for when a user starts typing
@client.event
async def on_typing(channel, user, when):
    log_event(DiscordEvent.USER_TYPING, {'channel': channel.name, 'user': user.name, 'when': when})

# Authenticate with Discord using your token
client.run('NDMyMDExNzgxODcyMDI1NjAx.GTSoCe.zSxu4hV7b7SKhKfZgWJ5XgH0xbxDLy7_SmZ0DI')
