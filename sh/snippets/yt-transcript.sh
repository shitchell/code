#!/usr/bin/env bash

declare -- PARAMS
# PARAMS+="&hl=en"
# PARAMS+="&xorb=2"
# PARAMS+="&xobt=3"
# PARAMS+="&xovt=3"
# PARAMS+="&cbrand=apple"
# PARAMS+="&cbr=Firefox"
# PARAMS+="&cbrver=123.0"
# PARAMS+="&c=WEB"
# PARAMS+="&cver=2.20240220.08.00"
# PARAMS+="&cplayer=UNIPLAYER"
# PARAMS+="&cos=Macintosh"
# PARAMS+="&cosver=14.3"
# PARAMS+="&cplatform=DESKTOP"

## Needed
### sparams
PARAMS+="&sparams=ip%2Cipbits%2Cexpire%2Cv%2Cei%2Ccaps%2Copi%2Cxoaf"
PARAMS+="&ipbits=0"
PARAMS+="&expire=1708606669"
PARAMS+="&v=E1KkQrFEl2I"
PARAMS+="&ei=XeLWZeeeMfaGy_sP2si66Ac"
PARAMS+="&caps=asr"
PARAMS+="&opi=112496729"
PARAMS+="&xoaf=5"
### this stuff
PARAMS+="&ip=0.0.0.0"
PARAMS+="&signature=7AC342B67875AE4A2546C16B0FFCE1F5D798403F.1C03F7B4E2B338E77B472216B5848F8CBA576903"
PARAMS+="&key=yt8"
PARAMS+="&lang=en-GB"
PARAMS+="&fmt=json3"

echo "using params: ${PARAMS}" >&2

curl "https://www.youtube.com/api/timedtext?${PARAMS}"

