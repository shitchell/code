#!/bin/bash

 tail -fn 100 $1 | stdbuf -o0 awk '{gsub(/\[.*/,"",$5); print "\n\033[32m" $1 " " $2 " " $3 "\n\033[0m- " $5; last=""; for(i=6;i<=NF;i++){last=last" "$i}; print ":" last}'