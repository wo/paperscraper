#!/usr/bin/env python3
import pytest
import os.path
from doctyper import doctyper
import scraper
from debug import debuglevel

debuglevel(3)

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

def test_simplepaper():
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/variations.pdf')
    doc.link.anchortext = 'Download'
    doc.link.context = 'Foo bar'
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 10200
    doc.numpages = 22
    assert doctyper.evaluate(doc) == 'article'

def test_pretendbook():
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/variations.pdf')
    doc.link.anchortext = 'Download'
    doc.link.context = 'Foo bar'
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt')) * 10
    doc.numwords = 10200 * 10
    doc.numpages = 22 * 10
    assert doctyper.evaluate(doc) == 'book'

def test_pretendreview():
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/variations.pdf')
    doc.link.anchortext = 'Review of xyz'
    doc.link.context = 'Review of xyz abc'
    doc.content = 'Hans Kamp: xyz, Oxford University Press 2009, 210 pages\n'
    doc.content += readfile(os.path.join(testdir, 'attitudes.txt'))[:1000]
    doc.numwords = 1000
    doc.numpages = 3
    assert doctyper.evaluate(doc) == 'review'

def test_notreview():
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/variations.pdf')
    doc.link.anchortext = 'xyz'
    doc.link.context = 'xyz forthcoming in Philosophical Review'
    doc.content = 'blah blah foo bar xyz\nForthcoming in The Philosophical Review\n'
    doc.content += readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 10200
    doc.numpages = 22
    assert doctyper.evaluate(doc) == 'article'


def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
