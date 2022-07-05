#!/bin/bash

katalonc=' /mnt/c/Users/smitchell/Programs/Katalon_Studio_Engine_Windows_64-8.2.5/Katalon_Studio_Engine_Windows_64-8.2.5/katalonc.exe'
K_PROJ="~/code/git/OPG Katalon/"
TS_NAME="IM"
K_PROF="DEV"
KRE_KEY="c5ac83be-fd88-4579-a759-5dc89ef1be8b"
K_ORG_ID="195136"
KTO_PROJ_ID="154312"

cmd="$(echo ${katalonc} -noSplash \
    -runMode=console \
    -projectPath="${K_PROJ}" \
    -retry=0 \
    -testSuitePath="Test Suites/${TS_NAME}" \
    -executionProfile="${K_PROF}" \
    -browserType='Chrome (headless)' \
    -apiKey="${KRE_KEY}" \
    -orgID="${K_ORG_ID}" \
    -testOpsProjectId="${KTO_PROJ_ID}")"
echo "$cmd"