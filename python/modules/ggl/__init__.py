__version__ = '0.1'
__all__ = ['maps', 'search', 'translate']

api_key_path = "/etc/gapi/api_key"

def load_api_key(path=None):
    global api_key
    
    if not path:
        path = api_key_path
    api_key = open(path).read()

load_api_key()

from . import maps
from . import search
from . import translate