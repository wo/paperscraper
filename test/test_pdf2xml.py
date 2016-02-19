#!/usr/bin/env python3
import pytest
import logging
import os.path
import os, sys, shutil
import json
from docparser.pdf2xml import pdf2xml

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

def test_pdftohtml():
    pdffile = os.path.join(testdir, 'simple.pdf')
    xmlfile = os.path.join(testdir, 'simple.pdf2.xml')
    pdf2xml.pdf2xml(pdffile, xmlfile, debug_level=3)
    with open(xmlfile, 'r') as f:
        xml = f.read()
        assert '<text top="247" left="314" width="288" height="23" font="0">Lorem ipsum dolor sit amet</text>' in xml
    os.remove(xmlfile)

def test_pdfocr():
    pdf2xml._debug_level = 3
    pdffile = os.path.join(testdir, 'simple.pdf')
    xmlfile = os.path.join(testdir, 'simple.ocr.xml')
    pdf2xml.pdf2xml(pdffile, xmlfile, use_ocr=True, debug_level=3)
    with open(xmlfile, 'r') as f:
        xml = f.read()
        assert '<text left="316" top="247" width="285" height="24" font="0">Lorern ipsum dolor sit amet</text>' in xml
    os.remove(xmlfile)

    
