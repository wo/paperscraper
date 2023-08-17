#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
import re
from opp.webpage import Webpage

def source(pagename):
    curpath = os.path.abspath(os.path.dirname(__file__))
    pagefile = os.path.join(curpath, 'sourcepages', pagename)
    with open(pagefile, 'r') as f:
        html = f.read()
    return html

def test_mongin(caplog):
    pagename = 'mongin.html'
    url = 'https://studies2.hec.fr/jahia/Jahia/cache/offonce/lang/en/mongin/pid/1072'
    page = Webpage(url, html=source(pagename))
    svars = page.session_variables()
    assert 'jsessionid' in svars
    testurl = 'https://studies2.hec.fr/jahia/webdav/site/hec/shared/sites/mongin/foo.pdf;jsessionid=123456'
    stripped = page.strip_session_variables(testurl)
    assert stripped == 'https://studies2.hec.fr/jahia/webdav/site/hec/shared/sites/mongin/foo.pdf;'

def test_utf8(caplog):
    pagename = 'philpapers-rec.html'
    url = 'https://blah.org'
    page = Webpage(url, html=source(pagename))
    assert 'Analytic' in page.text()

def test_broken_html():
    pagename = 'healey.html'
    url = 'https://blah.org'
    page = Webpage(url, html=source(pagename))
    targets = set(u for u in page.xpath('//a/@href') if re.search(r'.pdf$', u, re.I))
    assert targets
