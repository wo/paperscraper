#!/usr/bin/env python3
import pytest
import logging
import os.path
import os, sys, shutil
import scraper
from webpage import Webpage
import util
import docparser.webpageparser as pparser
from debug import debuglevel

debuglevel(4)

def test_SEP_Abilities():
    url = 'http://plato.stanford.edu/entries/abilities/'
    status, r = util.request_url(url)
    r.encoding = 'utf-8'
    doc = scraper.Doc(url=url, r=r)
    doc.page = Webpage(url, html=r.text)

    res = pparser.parse(doc)
    assert res == True
    assert doc.authors == ['John Maier']
    assert doc.title == 'Abilities'
    assert doc.abstract[:10] == 'In the acc'
    assert doc.abstract[-10:] == 'imes true.'
    assert 'General and specific abilities' in doc.content
    assert doc.numwords > 1000

def test_SEP_ActionPerception():
    url = 'http://plato.stanford.edu/entries/action-perception/'
    status, r = util.request_url(url)
    r.encoding = 'utf-8'
    doc = scraper.Doc(url=url, r=r)
    doc.page = Webpage(url, html=r.text)

    res = pparser.parse(doc)
    assert res == True
    assert doc.authors == ['Robert Briscoe', 'Rick Grush']
    assert doc.title == 'Action-based Theories of Perception'
    assert doc.abstract[:10] == 'Action is '
    assert doc.abstract[-10:] == 'd of view.'
    assert 'The tactual ideas' in doc.content
    assert doc.numwords > 1000

def test_not_SEP_article():
    url = 'http://plato.stanford.edu/index.html'
    status, r = util.request_url(url)
    r.encoding = 'utf-8'
    doc = scraper.Doc(url=url, r=r)
    doc.page = Webpage(url, html=r.text)

    res = pparser.parse(doc)
    assert res == False
