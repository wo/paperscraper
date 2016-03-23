#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
import json
from debug import debug, debuglevel
import scraper
import db

debuglevel(5)

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

@pytest.fixture(scope='module')
def testdb():
    """set up test database"""
    db.close()
    db.connection(db='test_opp')
    cur = db.cursor()
    for t in ('sources', 'links', 'docs'):
        cur.execute('DELETE FROM {}'.format(t))
    db.commit()
    query = "INSERT IGNORE INTO sources (sourcetype, url, status, last_checked) VALUES (%s, %s, %s, %s)"
    cur.execute(query, ('personal', 'http://umsu.de/papers/', 0, '2016-01-01 12:34'))
    cur.execute(query, ('personal', 'http://consc.net/papers.html', 1, None))
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
    li.update_db(filesize=1234)
    assert li.link_id > 0
    li2 = scraper.Link(source_id=1, url='http://umsu.de/papers/magnetism2.pdf')
    li2.load_from_db()
    assert li2.filesize == 1234

def test_Doc(testdb):
    doc = scraper.Doc(url='http://umsu.de/papers/magnetism.pdf')
    doc.update_db(authors='wo')
    assert doc.doc_id > 0
    doc2 = scraper.Doc(url='http://umsu.de/papers/magnetism.pdf')
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

def test_get_duplicate(testdb):
    doc = scraper.Doc(url='http://umsu.de/papers/driver-2011.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/driver-2011.pdf')
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 13940
    doc.numpages = 26
    doc.authors = 'Wolfang Schwarz'
    doc.title = 'Lost memories and useless coins: Revisiting the absentminded driver'
    doc.update_db()
    doc2 = scraper.Doc(url='http://download.springer.com/static/pdf/307/art%253A10.1007%252Fs11229-015-0699-z.pdf')
    doc2.link = scraper.Link(url=doc2.url)
    doc2.content = 'abcdefghjik'+readfile(os.path.join(testdir, 'attitudes.txt'))
    doc2.numwords = 14130
    doc2.numpages = 29
    doc2.authors = 'Wolfang Schwarz'
    doc2.title = 'Lost memories and useless coins: revisiting the absentminded driver'
    dupe = scraper.get_duplicate(doc2)
    assert dupe.doc_id == doc.doc_id

def test_process(testdb, caplog):
    source = scraper.Source(url='http://umsu.de/papers/')
    source.load_from_db()
    browser = scraper.Browser(use_virtual_display=False)
    browser.goto(source.url)
    source.set_html(browser.page_source)
    link = 'magnetism2.pdf'
    el = browser.find_element_by_xpath("//a[@href='{}']".format(link))
    url = source.make_absolute(link)
    li = scraper.Link(url=url, source=source, element=el)
    li.load_from_db()
    scraper.debuglevel(2)
    scraper.process_link(li, force_reprocess=True, keep_tempfiles=True)
    assert 'Against Magnetism' in caplog.text()
    assert 'is the view that' in caplog.text()

#def test_scrape(testdb):
#    src = scraper.Source(url='http://umsu.de/papers/')
#    src.load_from_db()
#    scraper.scrape(src)


def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()



