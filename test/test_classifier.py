#!/usr/bin/env python3
#
#  +-------------------------------------------------------------------------+
#  |                                                                         |
#  | MUST RUN WITH python -m pytest, NOT WITH pytest                         |
#  |                                                                         |
#  +-------------------------------------------------------------------------+
#
import pytest
import os.path
from opp.doctyper.classifier import DocClassifier, get_classifier
from opp.models import Doc
from opp.debug import debuglevel

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
    doc = Doc(url='http://umsu.de/papers/variations.pdf')
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    mc.train([doc], [True])
    mc.save()
    assert True
    
def test_classify():
    mc = DocClassifier(picklefile)
    ham = Doc(url='http://umsu.de/papers/variations.pdf')
    ham.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    spam = Doc(url='http://umsu.de/papers/spam.pdf')
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
    spam.content *= 50
    mc.train([ham, spam], [True, False])
    ham.content += 'foo bar'
    prob = mc.classify(ham)
    assert prob > 0.5
    
def test_philosophy():
    clf = get_classifier('philosophy')
    clf.load()
    if not clf.ready:
        print("skipping test_philosophy: no philosophy classifier")
        return
    doc = Doc(url='http://umsu.de/papers/variations.pdf')
    doc.content = readfile(os.path.join(testdir, 'attitudes.txt'))
    assert clf.classify(doc) > 0.6
    
def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
