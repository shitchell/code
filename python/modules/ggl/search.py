import re
import html
import requests
import urllib.parse
from . import api_key

class SearchResult:
    def __init__(self, result):
        if 'link' in result.keys():
            self._from_api(result)
        else:
            self._from_dep(result)
    
    def _from_api(self, result):
        self.url = result['link']
        self.title = result['title']
        self.snippet = result['snippet'].replace('\n', '')
    
    def _from_dep(self, result):
        self.title = html.unescape(result['titleNoFormatting'])
        self.snippet = result['content'].replace('\n', '')
        self.snippet = re.sub('<.*?>', '', self.snippet)
        self.snippet = html.unescape(self.snippet)
        self.url = result['url']

def web_search(query):
    url = 'https://www.googleapis.com/customsearch/v1?key={}&cx=008423659245751881210:glgiyod9irk&fields=items(link,title,snippet)&q={}'.format(api_key, urllib.parse.quote(query))
    req = requests.get(url)
    resp = req.json()
    
    return [SearchResult(x) for x in resp['items']]

def image_search(query):
    url = 'https://www.googleapis.com/customsearch/v1?key={}&cx=008423659245751881210:lyuoakwwzh8&searchType=image&fields=items(link,title,snippet)&q={}'.format(api_key, urllib.parse.quote(query))
    req = requests.get(url)
    resp = req.json()
    
    return [SearchResult(x) for x in resp['items']]
