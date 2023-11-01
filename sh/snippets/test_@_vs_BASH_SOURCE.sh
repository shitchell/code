#!/bin/bash
echo '## ${@}'
for ((i=0; i<=${#}; i++)); do
  echo "${i}: ${!i}"
done

echo
echo '## ${BASH_SOURCE[@]}'
for ((i=0; i<${#BASH_SOURCE[@]}; i++)); do
  echo "${i}: ${BASH_SOURCE[$i]}"
done
