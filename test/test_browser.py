#!/usr/bin/env python3
import pytest
import logging
import os.path
import time
import sys
import subprocess
from opp.browser import Browser, stop_browser
from opp.exceptions import PageLoadException
from opp.config import config

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'sourcepages')


def test_installation(caplog):
    from selenium import webdriver
    from selenium.webdriver.firefox.service import Service
    from selenium.webdriver.firefox.options import Options
    options = Options()
    options.add_argument('--headless')
    options.binary_location = config['binaries']['firefox']
    service = Service(config['binaries']['geckodriver'],
                      log_output=open("/tmp/geckodriver.log", "w"))
    driver = webdriver.Firefox(service=service, options=options)
    driver.get('https://www.umsu.de')
    assert 'philosopher' in driver.page_source
    driver.quit()
    with open("/tmp/geckodriver.log", "r") as f:
        assert 'running in headless mode' in f.read()

def test_startstop(caplog):
    num_browsers1 = count_processes('firefox-bin')
    caplog.set_level(logging.CRITICAL, logger='selenium')
    caplog.set_level(logging.DEBUG, logger='opp')
    b = Browser()
    time.sleep(1)
    stop_browser()
    b2 = Browser()
    time.sleep(1)
    stop_browser()
    num_browsers2 = count_processes('firefox-bin')
    assert num_browsers1 == num_browsers2

def test_status(caplog):
    caplog.set_level(logging.CRITICAL, logger='selenium')
    caplog.set_level(logging.DEBUG, logger='opp')
    b = Browser()
    src = 'file://'+testdir+'/umsu.html'
    b.goto(src)
    assert b.status == 200
    src = 'file://'+testdir+'/xxx.html'
    try:
        b.goto(src)
    except PageLoadException:
        assert b.status != 200
    stop_browser()

def test_reuse(caplog):
    caplog.set_level(logging.CRITICAL, logger='selenium')
    caplog.set_level(logging.DEBUG, logger='opp')
    b1 = Browser()
    src = 'file://'+testdir+'/umsu.html'
    b1.goto(src)
    b2 = Browser()
    b2.goto(src)
    assert b1 == b2
    stop_browser()

def count_processes(procname):
    ps = subprocess.Popen(('ps', 'aux'), stdout=subprocess.PIPE)
    output = ps.communicate()[0]
    pslines = output.decode('utf8').split('\n')
    return sum(1 for line in pslines if procname in line)
