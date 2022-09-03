#!/usr/bin/env python3
# -*- coding: utf-8 -*-
'''
This script counts down the seconds to some given time.

TODO:
  [ ] - modularize
  [ ] - account for skipping second ever 7.5 * 100 seconds?
  [ ] - fix negative time deltas
  [ ] - allow more customized output formats (allow for formatting strings)
  [ ] - allow for decimals / precision
  [ ] - improve documentaion
  [ ] - more type hinting
'''

import re
import time
import argparse
from dateutil.parser import parse
from datetime import datetime, timedelta

parser = argparse.ArgumentParser(description="count down to an event.")
p_output = parser.add_argument_group('output-format')
p_continue = parser.add_argument_group('continue')
#parser = argparse.ArgumentParser(description="Process some integers.")
parser.add_argument("timestring", nargs="+",
                    help="the time to count down to (tomorrow at 4pm)")
p_continue.add_argument("-c", "--continue", dest="cont", action="store_true",
                    help="continue displaying the time since the timestring after it passes")
p_continue.add_argument("-s", "--stop", action="store_true",
                    help="stop displaying the time until the timestring after it passes")
parser.add_argument("-d", "--delay", type=float, default=1,
                    help="time between updates (in seconds)")
parser.add_argument("-n", "--max-intervals", type=int, default=0,
                    help="stop counting down after n intervals")
parser.add_argument("-p", "--precision", type=int, default=0,
                    help="round the smallest unit to this many decimal places")
p_output.add_argument("-q", "--quiet", action="store_true",
                    help="don't print any output")
p_output.add_argument("-r", "--readable", action="store_true",
                    help="display time in human readable format")
p_output.add_argument("-T", "--tenths", action="store_true",
                    help="display time in seconds including tenths of a second")
p_output.add_argument("-S", "--seconds", action="store_true",
                    help="display time in seconds")
p_output.add_argument("-H", "--hours", action="store_true",
                    help="display time in hours")
p_output.add_argument("-D", "--days", action="store_true",
                    help="display time in days")
p_output.add_argument("-W", "--weeks", action="store_true",
                    help="display time in weeks")
p_output.add_argument("-M", "--months", action="store_true",
                    help="display time in months")
p_output.add_argument("-Y", "--years", action="store_true",
                    help="display time in years")
args = parser.parse_args()

# default to stopping if neither stop nor continue is provided
if not args.stop and not args.cont:
  args.stop = True

_substitutions = [
  ("noon", "12:00"),
  ("midnight", "00:00"),
  ("today", datetime.now().strftime("%B %d, %Y")),
  ("tomorrow", (datetime.now() + timedelta(days=1)).strftime("%B %d, %Y"))
]

def parse_timestring(timestring: str) -> datetime:
  '''
  Returns a datetime object given a time string. Uses dateutil.parser.parse with
  some extra keyword substitutions for 'noon', 'midnight', 'today', and
  'tomorrow'
  
  Examples:
  ```
  >>> parse_timestring("tomorrow at noon")
  >>> parse_timestring("December 20, 2021")
  >>> parse_timestring("Monday at 5pm")
  ```
  '''
  for keyword, substitution in _substitutions:
    timestring = re.sub(keyword, substitution, timestring, re.IGNORECASE)
  
  return parse(timestring)

def deltaiter(dtime: datetime, stop: bool = True) -> timedelta:
  '''
  Yields a time delta between now and the given datetime object.
  '''
  while not stop or (stop and dtime > datetime.now()):
    yield dtime - datetime.now()

def deltastr(delta: timedelta,
            seconds: bool = True,
            minutes: bool = True,
            hours: bool = True,
            days: bool = True,
            weeks: bool = False,
            months: bool = False,
            years: bool = False,
            precision: int = 0,
            keep_null: bool = False) -> str:
  total_seconds = delta.total_seconds()
  # determine which unis to calculate
  units = []
  if years:
    units.append(('years', 31556926))
  if months:
    units.append(('months', 2629743))
  if weeks:
    units.append(('weeks',  604800))
  if days:
    units.append(('days', 86400))
  if hours:
    units.append(('hours', 3600))
  if minutes:
    units.append(('minutes', 60))
  if seconds:
    units.append(('seconds', 1))
  # then calculate each, using i so we can determine if we're on the last unit
  # and need to calculate using precision
  delta_items = []
  for i in range(len(units)):
    if not total_seconds:
      # if we've no more seconds left, don't keep counting
      # i might potentially remove this, because i reckon it'll improve
      # efficiency far less often than it'll add an extra step
      # TODO: benchmark this function with and without this if statement
      break
    unit_name, unit_seconds = units[i]
    num_units = 0
    if i == len(units) - 1 and precision:
      num_units = round(total_seconds / unit_seconds, precision)
    else:
      num_units, total_seconds = divmod(total_seconds, unit_seconds)
      num_units = int(num_units)
    
    if num_units <= 0 and not keep_null:
      continue
    
    if num_units == 1:
      unit_name = unit_name[:-1]
    
    delta_items.append(f"{num_units:02} {unit_name}")
  
  return ", ".join(delta_items)

target = parse_timestring(" ".join(args.timestring))

numchars = 0
for delta in deltaiter(target, args.stop):
  dstr = deltastr(delta, precision=args.precision)
  # erase the last line
  print("\r" + " " * numchars, end="\r")
  print(dstr, end="", flush=True)
  numchars = len(dstr)
  time.sleep(args.delay)
