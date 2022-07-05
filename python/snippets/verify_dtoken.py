#!/usr/bin/env python

import os
import sys
import requests

USER_URL = "https://discordapp.com/api/v6/users/@me"

def fetch_data(token):
    """returns user data for the token"""
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "w3m",
        "Authorization": token
    }
    response = requests.get(USER_URL, headers=headers)
    if response.ok:
        return response.json()
    return None

if __name__ == "__main__":
    tokens = []

    # get any piped tokens
    if not os.isatty(0):
        data = sys.stdin.read()
        tokens.extend(data.split())

    # get tokens from command line args
    if len(sys.argv) > 1:
        tokens.extend(sys.argv[1:])

    for token in tokens:
        data = fetch_data(token)
        print(token)
        print(data)
