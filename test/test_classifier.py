#!/usr/bin/env python3
import pytest
import os.path
from doctyper.classifier import DocClassifier
import scraper
from debug import debuglevel

debuglevel(5)

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')
picklefile = os.path.join(curpath, '_test.pk')

def test_setup():
    mc = DocClassifier(picklefile)
    mc.reset()
    assert True

def test_train():
    mc = DocClassifier(picklefile)
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 10200
    doc.numpages = 22
    doc.meta_confidence = 92
    mc.train([doc], [True])
    mc.save()
    assert True
    
def test_classify():
    mc = DocClassifier(picklefile)
    doc = scraper.Doc(url='http://umsu.de/papers/variations.pdf')
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    doc.numwords = 10200
    doc.numpages = 22
    doc.meta_confidence = 92
    probs = mc.classify([doc])
    print(probs)
    assert probs[0] > 0.5
    
def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
