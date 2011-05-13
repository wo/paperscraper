#!/bin/bash
cd $(dirname "$0")
trap '' ERR
while true
do
    ./process_pages.pl
    RES=$?
    if [ $RES -eq 9 ]
    then
        exit
    fi
    ./process_links.pl
    RES=$?
    if [ $RES -eq 9 ]
    then
        exit
    elif [ $RES -eq 8 ]
    then
        echo "nothing to do; resting 5 min."
        sleep 300
    fi
done
