#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
import json
import scraper
import db

"""
To run these tests, create a test database called test_opp and
give the standard mysql user access to it.
"""

VDISPLAY = True

scraper.debuglevel(5)

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
    scraper.Source(
        url='http://umsu.de/papers/',
        sourcetype='personal',
        status=0,
        last_checked='2016-01-01 12:34').save_to_db()
    scraper.Source(
        url='http://consc.net/papers.html',
        sourcetype='personal',
        status=1).save_to_db()

def test_debug(caplog):
    scraper.debuglevel(4)
    scraper.debug(4, 'hi there')
    assert 'hi there' in caplog.text()
    scraper.debug(5, 'secret')
    assert 'secret' not in caplog.text()
    scraper.debuglevel(5)

def test_Source(testdb):
    src = scraper.Source(url='http://umsu.de/papers/')
    src.load_from_db()
    src.update_db(name="wo's weblog")
    src2 = scraper.Source(url='http://umsu.de/papers/')
    src2.load_from_db()
    assert src2.name == "wo's weblog"

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


@pytest.mark.parametrize(('published','context'), [
    (1, 'Basic structure and the value of equality, Philosophy and public affairs, 31: 4, 2003'),
    (1, 'Massimi, M. (2014) "Prescribing laws to nature", Kant-Studien 105, 491-508. [PDF] [journal link]'),
    (1, 'The Model-Theoretic Argument: From Skepticism to a New Understanding. The Brain in a Vat. Ed. S. Goldberg. Cambridge. 2014.'),
    (1, 'A Conception of Tarskian Logic. Pacific Philosophical Quarterly 70 (1989): 341-68.'),
    (0, 'Massimi, M. (forthcoming) "Grounds, modality and nomic necessity in the Critical Kant", in Massimi and Breitenbach (eds.) Kant and the Laws of Nature (Cambridge University Press). [PDF]'),
    (0, 'A lonelier contractualism'),
    (0,  'Counterpart Semantics. Unpublished Manuscript, 2011'),
    (1,  ' Review of Tychomancy\nIn Philosophy of Science 82 (2015): 313--320. (On JSTOR.)')
    ])
def test_context_suggests_published(context, published, caplog):
    res = scraper.context_suggests_published(context)
    assert res == published

def test_process(testdb, caplog):
    source = scraper.Source(url='http://umsu.de/papers/')
    source.load_from_db()
    browser = scraper.Browser(use_virtual_display=VDISPLAY)
    browser.goto(source.url)
    source.set_html(browser.page_source)
    link = 'options.pdf'
    el = browser.find_element_by_xpath("//a[@href='{}']".format(link))
    url = source.make_absolute(link)
    li = scraper.Link(url=url, source=source, element=el)
    li.load_from_db()
    scraper.debuglevel(2)
    scraper.process_link(li, force_reprocess=True, keep_tempfiles=True)
    scraper.debuglevel(5)
    assert 'Options and Actions' in caplog.text()
    assert 'But even if we know' in caplog.text()

#def test_scrape(testdb):
#    src = scraper.Source(url='http://umsu.de/papers/')
#    src.load_from_db()
#    scraper.scrape(src)


def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()



