import requests
import urllib.parse
from . import api_key

_translate_codes = [('afrikaans', 'af'), ('albanian', 'sq'), ('arabic', 'ar'), ('armenian', 'hy'), ('azerbaijani', 'az'), ('basque', 'eu'), ('belarusian', 'be'), ('bengali', 'bn'), ('bosnian', 'bs'), ('bulgarian', 'bg'), ('catalan', 'ca'), ('cebuano', 'ceb'), ('chichewa', 'ny'), ('chinese simplified', 'zh-cn'), ('chinese traditional', 'zh-tw'), ('croatian', 'hr'), ('czech', 'cs'), ('danish', 'da'), ('dutch', 'nl'), ('english', 'en'), ('esperanto', 'eo'), ('estonian', 'et'), ('filipino', 'tl'), ('finnish', 'fi'), ('french', 'fr'), ('galician', 'gl'), ('georgian', 'ka'), ('german', 'de'), ('greek', 'el'), ('gujarati', 'gu'), ('haitian creole', 'ht'), ('hausa', 'ha'), ('hebrew', 'iw'), ('hindi', 'hi'), ('hmong', 'hmn'), ('hungarian', 'hu'), ('icelandic', 'is'), ('igbo', 'ig'), ('indonesian', 'id'), ('irish', 'ga'), ('italian', 'it'), ('japanese', 'ja'), ('javanese', 'jw'), ('kannada', 'kn'), ('kazakh', 'kk'), ('khmer', 'km'), ('korean', 'ko'), ('lao', 'lo'), ('latin', 'la'), ('latvian', 'lv'), ('lithuanian', 'lt'), ('macedonian', 'mk'), ('malagasy', 'mg'), ('malay', 'ms'), ('malayalam', 'ml'), ('maltese', 'mt'), ('maori', 'mi'), ('marathi', 'mr'), ('mongolian', 'mn'), ('myanmar (burmese)', 'my'), ('nepali', 'ne'), ('norwegian', 'no'), ('persian', 'fa'), ('polish', 'pl'), ('portuguese', 'pt'), ('punjabi', 'ma'), ('romanian', 'ro'), ('russian', 'ru'), ('serbian', 'sr'), ('sesotho', 'st'), ('sinhala', 'si'), ('slovak', 'sk'), ('slovenian', 'sl'), ('somali', 'so'), ('spanish', 'es'), ('sudanese', 'su'), ('swahili', 'sw'), ('swedish', 'sv'), ('tajik', 'tg'), ('tamil', 'ta'), ('telugu', 'te'), ('thai', 'th'), ('turkish', 'tr'), ('ukrainian', 'uk'), ('urdu', 'ur'), ('uzbek', 'uz'), ('vietnamese', 'vi'), ('welsh', 'cy'), ('yiddish', 'yi'), ('yoruba', 'yo'), ('zulu', 'zu')]

class Translation:
    def __init__(self, result, to):
        self.lang_to = to
        self.lang_from = result['data']['translations'][0]['detectedSourceLanguage']
        self.text = result['data']['translations'][0]['translatedText']

def _get_translate_code(lang):
    lang = lang.lower()
    for pair in _translate_codes:
        if pair[0] == lang:
            return pair[1]

def _get_translate_lang(code):
    code = code.lower()
    for pair in _translate_codes:
        if pair[1] == code:
            return pair[0]

def translate(phrase, to="en"):
    url = 'https://www.googleapis.com/language/translate/v2?q={}&target={}&format=text&key={}'.format(urllib.parse.quote(phrase), to, api_key)
    req = requests.get(url)

    return Translation(req.json(), to)