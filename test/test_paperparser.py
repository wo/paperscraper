#!/usr/bin/env python3
import pytest
import logging
import os.path
import os, sys, shutil
import json
import scraper
import docparser.paperparser as paperparser

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

def test_enrich_xml():
    xmlfile = os.path.join(testdir, 'simple.xml')
    xmlfile2 = xmlfile+'2'
    shutil.copyfile(xmlfile, xmlfile2)
    
    doc = scraper.Doc(url='http://example.org/test.pdf')
    doc.source = scraper.Source(url='http://example.org', default_author='Hans Kamp')
    doc.source.set_html('<html>Hello</html>')
    doc.link = scraper.Link(url='http://example.org/test.pdf', source=doc.source)
    doc.link.anchortext = 'Example'
    doc.link.context = 'Example context'

    paperparser.enrich_xml(xmlfile2, doc)
    with open(xmlfile2, 'r') as f:
        xml = f.read()
        assert '<anchortext>Example</anchortext>' in xml
        assert 'Example context' in xml
        assert 'Hello' in xml
        assert 'example.org/test.pdf' in xml
        assert 'Hans Kamp' in xml

def test_extractor():
    xmlfile = os.path.join(testdir, 'simple.xml')
    jsonres = paperparser.extractor(xmlfile)
    assert jsonres and 'authors' in jsonres
