import re
import requests
import urllib.parse
from . import api_key

_travel_modes = ['driving', 'walking', 'bicycling', 'transit']
_units = ['metric', 'imperial']

class MapsDirections:
    def __init__(self, origin, destination, mode='driving', units='imperial', language='en', **kwargs):
        self.origin = origin
        self.destination = destination
        self.mode = mode
        self.units = units
        self.language = language
        self._generate_url(kwargs)
        self._load()

    def _load(self):
        req = requests.get(self._url)
        self._json = req.json()
        self.route = MapsRoute(self._json['routes'][0])
        # Update the origin and destination
        self.origin = self.route.origin
        self.destination = self.route.destination
    
    def _generate_url(self, kwargs):
        kwargs['key'] = api_key
        kwargs['origin'] = self.origin
        kwargs['destination'] = self.destination
        kwargs['mode'] = self.mode
        kwargs['units'] = self.units
        kwargs['language'] = self.language
        qs = ['{}={}'.format(x, urllib.parse.quote(kwargs[x])) for x in kwargs]
        self._url = 'https://maps.googleapis.com/maps/api/directions/json?' + '&'.join(qs)

class MapsRoute:
    def __init__(self, route):
        self._json = route
        self.summary = route['summary']
        route = route['legs'][0]
        self.duration = route['duration']['text']
        self.distance = route['distance']['text']
        self.origin = route['start_address']
        self.destination = route['end_address']
        self.steps = [MapsStep(x) for x in route['steps']]
    
    def __repr__(self):
        return '{} "{}"'.format(type(self), self.summary)

class MapsStep:
    def __init__(self, step):
        self._json = step
        self.mode = step['travel_mode'].lower()
        self.text = re.sub('<.*?>', '', step['html_instructions'])
        self.duration = step['duration']['text']
        self.distance = step['distance']['text']
        self._get_substeps()
        if step.get('transit_details'):
            self.transit_details = TransitDetails(step['transit_details'])
    
    def _get_substeps(self):
        self.steps = list()
        substeps = self._json.get('steps')
        if substeps:
            for step in substeps:
                self.steps.append(MapsStep(step))
    
    def __repr__(self):
        return '{} "{}"'.format(type(self), self.text)

class TransitDetails:
    def __init__(self, details):
        self._json = details
        self.vehicle = details.get('vehicle', {}).get('type', "")
        self.name = details['line'].get('name')
        self.short_name = details['line'].get('short_name')
        self.arrival = details['arrival_stop']['name']
        self.departure = details['departure_stop']['name']
        self.stops = details['num_stops']
        self.duration = _human_readable_seconds(details['arrival_time']['value'] - details['departure_time']['value'])

def _human_readable_seconds(seconds):
    minutes = int(seconds / 60)
    if minutes > 60:
        hours = int(minutes / 60)
        minutes = int(minutes % 60)
        return "{} hours {} mins".format(hours, minutes)
    return "{} mins".format(minutes)

def street_view(location):
    return "https://maps.googleapis.com/maps/api/streetview?size=640x400&location={}&key={}".format()