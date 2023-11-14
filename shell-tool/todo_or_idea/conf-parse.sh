#!/bin/bash
while read -r line; do
    if [[ $line =~ ^"["(.+)"]"$ ]]; then
        arrName=${BASH_REMATCH[1]}
        declare -A "$arrName"
    elif [[ $line =~ ^([_[:alpha:]][_[:alnum:]]*)"="(.*) ]]; then
        declare "${arrName}"["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
done < ./aa.conf

test11(){
    while read -r line;do
        if [[ "${line}" =~ ^[^#]$ ]]; then
            echo "${line}"
        fi
    done
}
test11 ~/aa.conf