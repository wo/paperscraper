#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
import subprocess
from browser import Browser

VDISPLAY = True

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'sourcepages')

def test_status(caplog):
    caplog.setLevel(logging.CRITICAL, logger='selenium')
    caplog.setLevel(logging.DEBUG, logger='opp')
    b = Browser(use_virtual_display=VDISPLAY)
    src = 'file://'+testdir+'/umsu.html'
    b.goto(src)
    assert b.status == 200
    src = 'file://'+testdir+'/xxx.html'
    b.goto(src)
    assert b.status == 404
    del b

def test_reuse(caplog):
    caplog.setLevel(logging.CRITICAL, logger='selenium')
    caplog.setLevel(logging.DEBUG, logger='opp')
    b1 = Browser(reuse_browser=True, use_virtual_display=VDISPLAY)
    src = 'file://'+testdir+'/umsu.html'
    b1.goto(src)
    b2 = Browser(reuse_browser=True, use_virtual_display=VDISPLAY)
    b2.goto(src)
    assert b1 == b2
    del b1
    del b2

def test_xvfb(caplog):
    caplog.setLevel(logging.CRITICAL, logger='selenium')
    caplog.setLevel(logging.DEBUG, logger='opp')
    b = Browser(use_virtual_display=True)
    src = 'file://'+testdir+'/umsu.html'
    b.goto(src)
    del b
    ps = subprocess.Popen(('ps', 'aux'), stdout=subprocess.PIPE)
    output = ps.communicate()[0]
    for line in output.decode('ascii').split('\n'):
        assert 'Xfvb' not in line


