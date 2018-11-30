#!/bin/bash

/usr/bin/python3 /home/wo/opp-tools/bin/scraperdaemon.py stop
sleep 2m
pkill -9 scraperdaemon
killall firefox-bin
killall geckodriver
killall -9 firefox-bin
killall -9 geckodriver
rm /tmp/opp-scraper.pid
rm -rvf /tmp/rust_mozprofile.*
rm -rvf /tmp/tmp*
/usr/bin/python3 /home/wo/opp-tools/bin/scraperdaemon.py start
