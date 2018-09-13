#!/bin/bash

/usr/bin/python3 /home/wo/opp-tools/bin/scraperdemon.py stop
sleep 2m
pkill -9 scraperdemon
killall firefox-bin
killall geckodriver
killall -9 firefox-bin
killall -9 geckodriver

