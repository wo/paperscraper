#!/usr/bin/env python3
import pytest
import os
from opp import util

def test_text_content():
    curpath = os.path.abspath(os.path.dirname(__file__))
    testdoc = os.path.join(curpath, 'testdocs', 'carnap-short.xml')
    content = util.text_content(testdoc)
    assert '<' not in content
    assert 'sys-' not in content
    assert 'systems' in content

def test_request_url():
    (status, r) = util.request_url('http://umsu.de/')
    assert status == 200
    assert r.content
    assert 'Hi' in r.text

def test_request_url_404():
    (status, r) = util.request_url('http://umsu.de/notfound/')
    assert status == 404

def test_request_url_maxsize():
    (status, r) = util.request_url('http://umsu.de/papers/generalising.pdf', maxsize=100000)
    assert status == 903

# TODO: more tests
