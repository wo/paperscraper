#!/usr/bin/env python3
import pytest
import logging
import os.path
import os, sys, shutil
import json
import pdftools.pdf2xml as pdf2xml
from debug import debuglevel

debuglevel(4)

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

def test_pdftohtml():
    pdffile = os.path.join(testdir, 'simple.pdf')
    xmlfile = os.path.join(testdir, 'simple.xml')
    pdf2xml.pdftohtml(pdffile, xmlfile)
    with open(xmlfile, 'r') as f:
        xml = f.read()
        assert '<text top="247" left="314" width="288" height="23" font="0">Lorem ipsum dolor sit amet</text>' in xml

def test_simple():
    pdffile = os.path.join(testdir, 'simple.pdf')
    xmlfile = os.path.join(testdir, 'simple.xml')
    engine = pdf2xml.pdf2xml(pdffile, xmlfile)
    assert engine == 'pdftohtml'
    with open(xmlfile, 'r') as f:
        xml = f.read()
        assert '<text top="247" left="314" width="288" height="23" font="0">Lorem ipsum dolor sit amet</text>' in xml

def test_ocr(caplog):
    pdffile = os.path.join(testdir, 'needsocr.pdf')
    xmlfile = os.path.join(testdir, 'needsocr.xml')
    engine = pdf2xml.pdf2xml(pdffile, xmlfile)
    assert 'no text in' in caplog.text()
    assert engine == 'ocr2xml'
    with open(xmlfile, 'r') as f:
        xml = f.read()
        assert 'Test Document' in xml

def test_mongin_ocr(caplog):
    pdffile = os.path.join(testdir, 'MonginRE03.pdf')
    xmlfile = os.path.join(testdir, 'MonginRE03.xml')
    engine = pdf2xml.pdf2xml(pdffile, xmlfile, ocr_ranges=[(1,3)])
    assert 'no text in' in caplog.text()
    assert engine == 'ocr2xml'
    with open(xmlfile, 'r') as f:
        xml = f.read()
        assert 'travail reexamine' in xml
