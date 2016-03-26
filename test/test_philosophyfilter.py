#!/usr/bin/env python3
import pytest
import os.path
from doctyper import philosophyfilter
import scraper
from debug import debug, debuglevel
import db

debuglevel(4)

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

@pytest.fixture(scope='module')
def setups():
    """set up classifier if not yet trained"""
    if philosophyfilter.is_ready():
        return
    db.close()
    db.connection(db='test_opp')
    ham = scraper.Doc(url='http://umsu.de/papers/magnetism2.pdf')
    ham.load_from_db()
    ham.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    ham.update_db()
    spam = scraper.Doc(url='http://umsu.de/papers/spam.pdf')
    spam.load_from_db()
    spam.content = """ 
       Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
       eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut
       enim ad minim veniam, quis nostrud exercitation ullamco laboris
       nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor
       in reprehenderit in voluptate velit esse cillum dolore eu
       fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
       proident, sunt in culpa qui officia deserunt mollit anim id est
       laborum. 
    """
    spam.update_db()
    cur = db.cursor()
    query = "SELECT cat_id FROM cats WHERE label=%s LIMIT 1"
    cur.execute(query, ('philosophy',))
    cat_id = cur.fetchall()[0]
    query = ("INSERT IGNORE INTO docs2cats (doc_id, cat_id, strength, is_training)"
             "VALUES (%s, %s, %s, %s)")
    cur.execute(query, (ham.doc_id, cat_id, 1, 1))
    cur.execute(query, (spam.doc_id, cat_id, 0, 1))
    philosophyfilter.update()

def test_gooddoc(setups):
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    assert philosophyfilter.evaluate(doc) > 0.6

def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
