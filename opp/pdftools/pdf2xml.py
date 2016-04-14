#!/usr/bin/env python3
import re
import sys
import os
from os.path import abspath, dirname, join, exists
import shutil
import subprocess
from debug import debug, debuglevel
from pdftools.ocr2xml import ocr2xml
from pdftools.doctidy import doctidy
from pdftools.pdftools import pdfcut
from exceptions import *

PDFTOHTML = '/usr/bin/pdftohtml'
PERL = '/usr/bin/perl'

PATH = abspath(dirname(__file__))

def pdf2xml(pdffile, xmlfile, keep_tempfiles=False, ocr_ranges=None):
    """
    converts pdf to xml using pdftohtml or, if that fails, ocr2xml;
    returns 'pdftohtml' or 'ocr2xml' depending on which process was
    used. ocr_ranges (optional) is a list of pairs such as
    [(1,3),(7,10)] which would specify that only pages 1-3 and 7-10
    should get ocr'ed.
            
    TODO: check quality to see if ocr is needed?
    """
    if not exists(pdffile):
        raise FileNotFoundError('{} not found'.format(pdffile))
    # first try pdftohtml
    try:
        pdftohtml(pdffile, xmlfile)
        return 'pdftohtml'
    except NoTextInPDFException:
        debug(2, "no text in xml produced by pdftohtml")
    except Exception as e:
        debug(2, "pdftohtml failed: %s -- %s", pdffile, str(e))
    # then try ocr2xml (not catching exceptions here)
    if ocr_ranges:
        shortened_pdf = pdffile.rsplit('.')[0] + '-short.pdf'
        pdfcut(pdffile, shortened_pdf, ocr_ranges)
        pdffile = shortened_pdf
    ocr2xml(pdffile, xmlfile, keep_tempfiles=keep_tempfiles)
    return 'ocr2xml'

def pdftohtml(pdffile, xmlfile):
    cmd = [PDFTOHTML, 
           '-i',            # ignore images
           '-xml',          # xml output
           '-enc', 'UTF-8',
           '-nodrm',        # ignore copy protection
           pdffile,
           xmlfile]
    debug(2, ' '.join(cmd))
    try:
        stdout = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=10)
    except subprocess.CalledProcessError as e:
        debug(1, e.output)
        raise
    if not exists(xmlfile):
        raise PdftohtmlFailedException(stdout)
    xml = readfile(xmlfile)
    if not xml_ok(xml):
        debug(4, "No text in pdf: %s", xml)
        raise NoTextInPDFException
    else:
        debug(3, "pdftohtml output ok")
    writefile(xmlfile, fix_pdftohtml(xml))
    doctidy(xmlfile)
    
def xml_ok(xml):
    if not xml:
        return False
    text_pattern = re.compile('<text.+?>.*[a-z]{5}.*<')
    if not text_pattern.search(xml):
        return False
    m = re.search('<page number="2".+?</page', xml, re.DOTALL)
    if not m:
        # one-page document with text: OK
        return True
    # if more than one page, make sure either second or third page
    # contains text (sometimes the coverpage isn't scanned, but the
    # rest is, so that pdftohtml only works on the coverpage):
    if text_pattern.search(m.group(0)):
        return True
    # no text on page 2, must be text on page 3:
    m = re.search('<page number="3".+?</page', xml, re.DOTALL)
    if not m:
        # two-page document with no text on page 2: not OK
        return False
    if text_pattern.search(m.group(0)):
        return True
    return False

def fix_pdftohtml(xml):
    # strip anchor tags inserted by pdftohtml for footnotes:
    xml = re.sub('<a[^>]+>(.+?)</a>', r'\1', xml)
    return xml;

def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
        
def writefile(path, txt):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(txt)

