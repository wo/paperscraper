#!/usr/bin/env python3
import pytest
import logging
import os.path
import os, sys, shutil
import json

import scraper
import docparser.pdfparser as pdfparser

def test_enrich_xml():
    curpath = os.path.abspath(os.path.dirname(__file__))
    testdir = os.path.join(curpath, 'testdocs')
    xmlfile = os.path.join(testdir, 'test.pdf.xml')
    xmlfile2 = xmlfile+'2'
    shutil.copyfile(xmlfile, xmlfile2)
    
    doc = scraper.Doc(url='http://example.org/test.pdf')
    doc.source = scraper.Source(url='http://example.org', default_author='Hans Kamp')
    doc.source.set_html('<html>Hello</html>')
    doc.link = scraper.Link(url='http://example.org/test.pdf', source=doc.source)
    doc.link.anchortext = 'Example'
    doc.link.context = 'Example context'

    pdfparser.enrich_xml(xmlfile2, doc)
    with open(xmlfile2, 'r') as f:
        xml = f.read()
        assert '<anchortext>Example</anchortext>' in xml
        assert 'Example context' in xml
        assert 'Hello' in xml
        assert 'example.org/test.pdf' in xml
        assert 'Hans Kamp' in xml

