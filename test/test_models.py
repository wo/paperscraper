#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
import json
from datetime import datetime
from opp.models import Source, Link, Doc
from opp.debug import debuglevel
from opp import db

"""
To run these tests, create a test database called test_opp and
give the standard mysql user access to it.
"""

VDISPLAY = True

debuglevel(5)

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

@pytest.fixture(scope='module')
def testdb():
    """set up test database"""
    db.close()
    db.connect(db='test_opp')
    cur = db.cursor()
    for t in ('sources', 'links', 'docs'):
        cur.execute('DELETE FROM {}'.format(t))
    db.commit()
    Source(
        url='https://www.umsu.de/writing/',
        sourcetype='personal',
        status=0,
        last_checked=datetime.now()).save_to_db()
    Source(
        url='https://consc.net/papers.html',
        sourcetype='personal',
        status=1).save_to_db()

def test_Source(testdb, caplog):
    caplog.set_level(logging.DEBUG, logger='opp')
    src = Source(url='https://www.umsu.de/writing/')
    src.load_from_db()
    assert type(src.last_checked) is datetime
    assert type(src.found_date) is datetime
    src.update_db(name="wo's weblog")
    src2 = Source(url='https://www.umsu.de/writing/')
    src2.load_from_db()
    assert src2.name == "wo's weblog"

def test_Link(testdb, caplog):
    caplog.set_level(logging.DEBUG, logger='opp')
    src = Source(url='https://www.umsu.de/writing/')
    src.load_from_db()
    li = Link(source_id=src.source_id, url='https://www.umsu.de/writing/magnetism2.pdf')
    li.update_db(filesize=1234)
    assert li.link_id > 0
    li2 = Link(source_id=src.source_id, url='https://www.umsu.de/writing/magnetism2.pdf')
    li2.load_from_db()
    assert li2.filesize == 1234

def test_Doc(testdb, caplog):
    caplog.set_level(logging.DEBUG, logger='opp')
    doc = Doc(url='https://www.umsu.de/writing/magnetism.pdf')
    doc.update_db(authors='wo')
    assert doc.doc_id > 0
    doc2 = Doc(url='https://www.umsu.de/writing/magnetism.pdf')
    doc2.load_from_db()
    assert doc2.authors == 'wo'

