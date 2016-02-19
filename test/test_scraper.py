#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
import json

import scraper
import db

@pytest.fixture(scope='module')
def testdb():
    """set up test database"""
    db.close()
    db.connection(db='test_opp')
    cur = db.cursor()
    for t in ('sources', 'links', 'docs'):
        cur.execute('DELETE FROM {}'.format(t))
    db.commit()
    query = "INSERT IGNORE INTO sources (type, url, status, last_checked) VALUES (%s, %s, %s, %s)"
    cur.execute(query, (1, 'http://umsu.de/papers/', 0, '2016-01-01 12:34'))
    cur.execute(query, (1, 'http://consc.net/papers.html', 1, None))
    db.commit()

def test_debug(caplog):
    scraper.debuglevel(4)
    scraper.debug(4, 'hi there')
    assert 'hi there' in caplog.text()
    scraper.debug(5, 'secret')
    assert 'secret' not in caplog.text()

def test_Source(testdb):
    src = scraper.Source(url='http://umsu.de/papers/')
    src.load_from_db()
    src.name = "wo's weblog"
    src.update_db()
    src2 = scraper.Source(url='http://umsu.de/papers/')
    src2.load_from_db()
    assert src.name == "wo's weblog"

def test_Link(testdb):
    li = scraper.Link(source_id=1, url='http://umsu.de/papers/magnetism2.pdf')
    li.load_from_db()
    li.update_db(filesize=1234)
    assert li.link_id > 0
    li2 = scraper.Link(source_id=1, url='http://umsu.de/papers/magnetism2.pdf')
    li2.load_from_db()
    assert li2.filesize == 1234

def test_Doc(testdb):
    doc = scraper.Doc(url='http://umsu.de/papers/magnetism2.pdf')
    doc.load_from_db()
    doc.update_db(authors='wo')
    assert doc.doc_id > 0
    doc2 = scraper.Doc(url='http://umsu.de/papers/magnetism2.pdf')
    doc2.load_from_db()
    assert doc2.authors == 'wo'

def test_next_source(testdb):
    src = scraper.next_source()
    assert src.url == 'http://consc.net/papers.html'

def test_check_steppingstone():
    examples = [
        ('http://philpapers.org/rec/CHACT', 'http://consc.net/papers/soames.pdf')
        # TODO: add more
    ]
    for (url, target) in examples:
        status,r = scraper.util.request_url(url)
        if status != 200:
            print('error %s at steppingstone page %s', status, url)
            continue
        r.encoding = 'utf-8'
        page = scraper.Webpage(url, html=r.text)
        t = scraper.check_steppingstone(page)
        assert t == target


#def test_scrape(testdb):
#    src = scraper.Source(url='http://umsu.de/papers/')
#    src.load_from_db()
#    scraper.scrape(src)





