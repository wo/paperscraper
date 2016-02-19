#!/usr/bin/env python3
import pytest
import shutil
import subprocess
import os.path
import sys

curpath = os.path.abspath(os.path.dirname(__file__))
binpath = os.path.join(curpath, os.path.pardir, 'bin')
daemonbin = os.path.join(binpath, 'scraperdaemon.py')

PIDFILE = '/tmp/opp-scraper.pid'

def calldaemon(cmd):
    cmd = [daemonbin, cmd] 
    stdout = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=5)
    return stdout

def test_1_startdaemon():
    if os.path.exists(PIDFILE):
        print("daemon seems to be running already, restarting")
        calldaemon('stop')
    calldaemon('start')
    assert os.path.exists(PIDFILE)

def test_2_stopdaemon():
    calldaemon('stop')
    assert not os.path.exists(PIDFILE)


