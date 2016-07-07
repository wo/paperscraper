#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
import json
from datetime import datetime
from opp import scraper
from opp.models import Source, Link, Doc
from opp import db
from opp.debug import debug, debuglevel

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
    db.connection(db='test_opp')
    cur = db.cursor()
    for t in ('sources', 'links', 'docs'):
        cur.execute('DELETE FROM {}'.format(t))
    db.commit()
    Source(
        url='http://umsu.de/papers/',
        sourcetype='personal',
        status=0,
        last_checked=datetime.now()).save_to_db()
    Source(
        url='http://consc.net/papers.html',
        sourcetype='personal',
        status=1).save_to_db()

def test_debug(caplog):
    debuglevel(4)
    debug(4, 'hi there')
    assert 'hi there' in caplog.text()
    debug(5, 'secret')
    assert 'secret' not in caplog.text()
    debuglevel(5)

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
    doc = Doc(url='http://umsu.de/papers/driver-2011.pdf')
    doc.link = Link(url='http://umsu.de/papers/driver-2011.pdf')
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 13940
    doc.numpages = 26
    doc.authors = 'Wolfang Schwarz'
    doc.title = 'Lost memories and useless coins: Revisiting the absentminded driver'
    doc.update_db()
    doc2 = Doc(url='http://download.springer.com/static/pdf/307/art%253A10.1007%252Fs11229-015-0699-z.pdf')
    doc2.link = Link(url=doc2.url)
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
    (0, 'Counterpart Semantics. Unpublished Manuscript, 2011'),
    (1, ' Review of Tychomancy\nIn Philosophy of Science 82 (2015): 313--320. (On JSTOR.)'),
    (1, 'Bertrand Russell,\nHerbrand\'s Theorem, and the assignment statement,\nArtificial Intelligence and Symbolic Computation, Springer Lecture Notes in Artificial Intelligence 1476, pp 14--28, 1998.'),
    (1, 'The Language of Thought, for The Routledge Companion to Philosophy of Psychology, John Symons and Paco Calvo, editors, 2009.'),
    (1, 'The Mind is not the Software of the Brain (Even if it is Computational)” - on ideas that motivate the ethics of futuristic brain enhancements, as well as computationalism in cognitve science.\n•The Metaphysics of Uploading, forthcoming in a special issue of the Journal of Consciousness Studies. (Symposium on a piece by David Chalmers, with his response.)  Reprinted in Uploaded Minds (with postscript), Russell Blackford (ed.) Wiley-Blackwell, 2014.'),
    ])
def test_context_suggests_published(context, published, caplog):
    res = scraper.context_suggests_published(context)
    assert res == published

def test_process_file():
    doc = Doc(filetype='pdf')
    doc.link = Link(url='foo')
    doc.link.context = 'Lorem ipsum dolor sit amet'
    doc.link.anchortext = 'Lorem ipsum dolor sit amet'
    doc.source = Source(url='foo', html='<b>Lorem ipsum dolor sit amet</b>')
    doc.tempfile = os.path.join(testdir, 'simple.pdf')
    scraper.process_file(doc)
    assert doc.title == 'Lorem ipsum dolor sit amet'

def test_process_link(testdb, caplog):
    source = Source(url='http://umsu.de/papers/')
    source.load_from_db()
    browser = scraper.Browser(use_virtual_display=VDISPLAY)
    browser.goto(source.url)
    source.set_html(browser.page_source)
    link = 'options.pdf'
    el = browser.find_element_by_xpath("//a[@href='{}']".format(link))
    url = source.make_absolute(link)
    li = Link(url=url, source=source, element=el)
    li.load_from_db()
    debuglevel(2)
    scraper.process_link(li, force_reprocess=True, keep_tempfiles=True)
    debuglevel(5)
    assert 'Options and Actions' in caplog.text()
    assert 'But even if we know' in caplog.text()

def test_scrape(testdb):
    src = Source(url='http://umsu.de/papers/')
    src.load_from_db()
    scraper.scrape(src)


def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()



