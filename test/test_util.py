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

