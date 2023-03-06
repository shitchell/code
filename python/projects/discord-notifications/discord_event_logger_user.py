import enum
import json
import subprocess
import sys
import time

import discord

USER_TYPING_DELAY = 300  # notification if a user starts typing after this many seconds


class DiscordEvent(enum.Enum):
    MESSAGE = "message"
    MENTION = "mention"
    USER_MENTION = "user_mention"
    USER_STATUS = "user_status"
    USER_TYPING_DM = "user_typing_dm"
    USER_TYPING_GUILD = "user_typing_guild"


# class DiscordMessageEvent(DiscordEvent):
    # MESSAGE = "message"
    # MENTION = "mention"
    # USER_MENTION = "user_mention"
# 
# 
# class DiscordTypingEvent(Enum):
    # USER_TYPING_DM = "user_typing_dm"
    # USER_TYPING_GUILD = "user_typing_guild"
# 
# 
# class DiscordStatusEvent(DiscordEvent):
    # ONLINE_STATUS = "status_update"


# Create a new client object
client = discord.Client()

# function to log event and data
typing_timestamps = dict()
user_statuses = dict()
last_event = ()
log_path: str = sys.argv[1] if len(sys.argv) > 1 else "discord-user-events.log"
log_file = open(log_path, "a")


def log_event(event: DiscordEvent, data: dict, display_str = None):
    global typing_timestamps, last_event

    # For some reason we seem to get a lot of duplicate events, so skip those
    this_event = (event, data)
    if last_event == this_event:
        return
    else:
        last_event = this_event

    # Logging stuffs
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {event.value} -- {json.dumps(data, default=str)}" if not display_str else f"[{ts}] {display_str}"

    # - PRINT an event to the console if it's a personal mention, user typing in our
    #   DMs, a friend changing their status, or a DM
    # - WRITE an event to the log file always
    if (
        event
        in (
            DiscordEvent.USER_MENTION,
            DiscordEvent.USER_TYPING_DM,
        )
        or (
            event == DiscordEvent.USER_STATUS
            and ("user" not in data or data["user"] in client.user.friends)
        )
        or (
            event == DiscordEvent.MESSAGE
            and (data["channel"] == "DMChannel" or data["user"] in client.user.friends)
        )
    ):
        print(line, flush=True)
        # If the event is a user typing, then send a notification to my phone
        if event == DiscordEvent.USER_TYPING_DM:
            # Only notify when the user has gone >5 minutes without a message
            last_ts = typing_timestamps.get(data["user"], None)
            if last_ts and (time.time() - last_ts > USER_TYPING_DELAY):
                pushbullet(f"{data['user']} is typing...")
            else:
                typing_timestamps[data["user"]] = time.time()

    # Always log it to the log file
    data = {"timestamp": ts, "event": event.name, **data}
    print(data, file=log_file, flush=True)


def pushbullet(message: str):
    subprocess.run(["pb", "push", f"[dNotify] {message}"])


# Use the on_ready() event to know when the bot is connected and authenticated
@client.event
async def on_ready():
    log_event(DiscordEvent.USER_STATUS, {"status": "authenticated"}, "client authenticated!")


# Use the on_message() event to listen for new messages
@client.event
async def on_message(message):
    event = DiscordEvent.MESSAGE
    if isinstance(message.channel, discord.channel.DMChannel):
        channel_name = "DMChannel"
    else:
        channel_name = f"{message.guild}#{message.channel}"
    if message.mention_everyone:
        event = DiscordEvent.MENTION
    elif message.mentions:
        for user in message.mentions:
            if user.id == client.user.id:
                event = DiscordEvent.USER_MENTION
                break
    attachments_str = ""
    if message.attachments:
        attachments_count = len(message.attachments)
        s = "s" if attachments_count != 1 else ""
        if channel_name == "DMChannel":
            attachments_files = " - ".join(a.url for a in message.attachments)
        else:
            attachments_files = ", ".join(a.filename for a in message.attachments)
        attachments_str = f" ({attachments_count} attachment{s}: {attachments_files})"
    log_event(
        event,
        {"channel": channel_name, "user": message.author, "content": message.content, "attachments": message.attachments},
        f"{message.author} in {channel_name} -> {message.content}{attachments_str}"
    )


# Use the on_member_update() event to listen for user status message changes
@client.event
async def on_member_update(before, after):
    global user_statuses
    
    before_status = {"mobile": before.is_on_mobile(), "status": before.raw_status}
    after_status = {"mobile": after.is_on_mobile(), "status": after.raw_status}
    user = after

    if before_status != after_status:
        # Check if the user status is logged and has actually changed
        if user in user_statuses and user_statuses[user] == after_status:
            return
        
        # Update the user's current status
        user_statuses[user] = after_status
        
        # Set up the display string
        before_mobile = f" (mobile)" if before.is_on_mobile() else ""
        after_mobile = f" (mobile)" if after.is_on_mobile() else ""

        # Log it
        log_event(
            DiscordEvent.USER_STATUS,
            {"user": user, "before": before_status, "after": after_status},
            f"{user}: {before.raw_status}{before_mobile} -> {after.raw_status}{after_mobile}"
        )


# Listen for when a user starts typing
@client.event
async def on_typing(channel, user, when):
    if isinstance(channel, discord.channel.DMChannel):
        channel_name = "DMChannel"
        event = DiscordEvent.USER_TYPING_DM
    else:
        channel_name = f"{channel.guild}#{channel.name}"
        event = DiscordEvent.USER_TYPING_GUILD
    log_event(
        event,
        {"channel": channel_name, "user": user.name, "when": when},
        f"{user} is typing in {channel_name}"
    )


# Authenticate with Discord using your token
client.run("NDMyMDExNzgxODcyMDI1NjAx.Gan4Ip.2G7fDHEqBASUXGyHdQZywN0C1ccSDI5Cm0BoAw")
