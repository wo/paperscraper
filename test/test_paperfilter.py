#!/usr/bin/env python3
import pytest
import os.path
from doctyper import paperfilter
import scraper

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

def test_gooddoc():
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/variations.pdf')
    doc.link.anchortext = 'Download'
    doc.link.context = 'Foo bar'
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 10200
    doc.numpages = 22
    doc.meta_confidence = 92
    assert paperfilter.evaluate(doc) > 0.98

def test_gooddoc_badlink():
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/variations.pdf')
    doc.link.anchortext = 'slides'
    doc.link.context = 'The slides for my talk'
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 10200
    doc.numpages = 22
    doc.meta_confidence = 92
    assert paperfilter.evaluate(doc) < 0.6

def test_cv():
    doc = scraper.Doc(url='http://umsu.de/papers/cv.pdf')
    doc.link = scraper.Link(url='http://umsu.de/papers/cv.pdf')
    doc.link.anchortext = 'CV'
    doc.link.context = 'CV'
    doc.content = readfile(os.path.join(testdir, 'cv.txt'))
    doc.numwords = 10200
    doc.numpages = 22
    doc.meta_confidence = 92
    assert paperfilter.evaluate(doc) < 0.4
    
def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
