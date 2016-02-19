#!/usr/bin/env python3
import re
import sys
import os
from os.path import abspath, dirname, join, exists
import shutil
import subprocess
import logging
from .ocr2xml import ocr2xml
from .exceptions import *

PDFTOHTML = '/usr/bin/pdftohtml'
PERL = '/usr/bin/perl'

PATH = abspath(dirname(__file__))

logger = logging.getLogger('opp')

def pdf2xml(pdffile, xmlfile, use_ocr=False, debug_level=0, keep_tempfiles=False):
    global _debug_level
    _debug_level = debug_level
    if not exists(pdffile):
        raise FileNotFoundError('{} not found'.format(pdffile))
    if not use_ocr:
        try:
            pdftohtml(pdffile, xmlfile)
        except NoTextInPDFException:
            return None
        except Exception as e:
            logger.warning("pdftohtml failed: %s -- %s", pdffile, str(e))
            return None
    else:
        try:
            ocr2xml(pdffile, xmlfile, debug_level=_debug_level, keep_tempfiles=keep_tempfiles)
        except NoTextInPDFException:
            return None
        except MalformedPDFError:
            logger.warning("MalformedPDFError: %s", pdffile)
        except Ocr2xmlFailedException:
            logger.warning("ocr2xml failed on %s", pdffile)
        except Exception as e:
            logger.warning("ocr2xml failed: %s -- %s", pdffile, str(e))
            return None
    doctidy(xmlfile)
    return True

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
    writefile(xmlfile, fix_pdftohtml(xml))
    
def doctidy(xmlfile):
    global _debug_level
    cmd = [PERL, join(PATH, 'Doctidy.pm'), xmlfile]
    if _debug_level > 4:
        cmd.insert(2, '-v')
    debug(2, ' '.join(cmd))
    try:
        stdout = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=10)
    except subprocess.CalledProcessError as e:
        debug(1, e.output)
        raise
    if _debug_level > 4:
        debug(5, stdout.decode('utf-8'))

def xml_ok(xml):
    if not xml:
        return False
    text_pattern = re.compile('<text.+?>.*[a-z]{5}.*<')
    if not text_pattern.search(xml):
        return False
    m = re.search('<page number="2".+?</page', xml)
    if not m:
        # one-page document with text: OK
        return True
    # if more than one page, make sure either second or third page
    # contains text (sometimes the coverpage isn't scanned, but the
    # rest is, so that pdftohtml only works on the coverpage):
    if text_pattern.search(m.group(0)):
        return True
    # no text on page 2, must be text on page 3:
    m = re.search('<page number="3".+?</page', xml)
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

def fix_ocr(xml):
    # fix some common OCR mistakes:
    xml = re.sub('(?<=[a-z])0(?=[a-z])', 'o', xml) # 0 => o
    xml = re.sub('(?<=[A-Z])0(?=[A-Z])', 'o', xml) # 0 => O
    xml = re.sub('(?<=[a-z])1(?=[a-z])', 'i', xml) # 1 => i
    xml = re.sub('. .u \&\#174\;', '', xml)        # the JSTOR logo
    return xml

def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
        
def writefile(path, txt):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(txt)

_debug_level = 0

def debug(level, msg, *args):
    if _debug_level >= level:
        logger.debug(msg, *args)

