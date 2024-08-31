#!/usr/bin/env bash

for acc in /as_shared/nxa/*/*/FileMgr/accounts/*; do test -d "${rdcs:=${acc}/rdcs}" || mkdir -pv --mode=777 "${rdcs}"; rdcs=; done
