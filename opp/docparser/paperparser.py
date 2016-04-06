#!/usr/bin/env python3
import logging
import re
import os
from os.path import abspath, dirname, join
import subprocess
import json
from pdftools.pdftools import pdfcut
from pdftools.pdf2xml import pdf2xml
from pdftools.ocr2xml import ocr2xml
from debug import debug, debuglevel

PERL = '/usr/bin/perl'

logger = logging.getLogger('opp')
path = abspath(dirname(__file__))

def parse(doc, keep_tempfiles=False):
    """
    tries to enrich Doc object by metadata (authors, title, abstract),
    extracted from the associated xml file; may crate tempfiles for ocr
    """
    xmlfile = doc.xmlfile
    # We have to pass all relevant information about the Doc object to
    # the perl Extractor. We do that by adding it to the xml
    # file. (This is a hopefully temporary hack that makes the xml
    # invalid.)
    enrich_xml(xmlfile, doc)
    OCR_IF_CONFIDENCE_BELOW = 0.8
    parse1 = extractor(xmlfile)
    if parse1:
        # add the Perl output to the Doc object:
        enrich_doc(doc, parse1)
        if doc.ocr or parse1['meta_confidence'] >= OCR_IF_CONFIDENCE_BELOW:
            return True 
        else:
            debug(1, 'confidence %s too low, trying ocr', parse1['meta_confidence'])
    else:
        # e.g., Extractor timeout
        logger.warning('extractor failed on %s, giving up', doc.url)
        return False
    
    # Since we only need author/title/abstract, we don't need to OCR
    # more than the first few pages (depending on doc length):
    if doc.numpages < 5:
        ocr_ranges = [(1,doc.numpages)]
    elif doc.numpages < 50:
        ocr_ranges = [(1,4)]
    else:
        # may need to skip lengthy toc, table of figures, etc. before
        # reaching normal content to figure out default fontsize etc.: 
        ocr_ranges = [(1,4),(20,24)]
    shortened_pdf = doc.tempfile.rsplit('.')[0] + '-short.pdf'
    shortened_xml = doc.tempfile.rsplit('.')[0] + '-short.xml'
    try:
        pdfcut(doc.tempfile, shortened_pdf, ocr_ranges)
    except Exception as e:
        debug(1, 'pdfcut failed, sticking with pdftohtml results: %s', e)
        # stick with pdftohtml results, so return value is True
        return True
    try:
        ocr2xml(shortened_pdf, shortened_xml, keep_tempfiles=keep_tempfiles)
    except Exception as e:
        debug(1, 'ocr failed, sticking with pdftohtml results: %s', e)
        if not keep_tempfiles:
            os.remove(shortened_pdf)
        return True
    enrich_xml(shortened_xml, doc)
    parse2 = extractor(shortened_xml)
    if parse2 and parse1:
        # compare results:
        same_authors = (parse1['authors'] == parse2['authors'])
        same_title = (strip_markup(parse1['title']) == strip_markup(parse2['title']))
        same_abstract = (strip_markup(parse1['abstract']) == strip_markup(parse2['abstract']))
        if same_authors and same_title and same_abstract:
            debug(1, "pdftohtml and pdfocr results agree")
            doc.meta_confidence *= 1.05
        else:
            # If pdftohtml and pdfocr produce different results, it's
            # not obvious what we should do. We could go with whatever
            # has greater meta_confidence, but meta_confidence doesn't
            # track things like silly cApiTAlization in titles, it
            # punishes results with more authors, etc. For now, let's
            # go with the ocr result and significantly lower
            # meta_confidence to flag the fact that either pdftohtml
            # or pdfocr produced false metadata.
            debug(1, "pdftohtml and pdfocr results disagree, using ocr results")
            if not same_authors:
                debug(1, "authors: '%s' vs '%s'", parse1['authors'], parse2['authors'])
                doc.meta_confidence *= 0.8
            if not same_title:
                debug(1, "title: '%s' vs '%s'", parse1['title'], parse2['title'])
                doc.meta_confidence *= 0.8
            if not same_abstract: 
                debug(1, "abstract: '%s' vs '%s'", parse1['abstract'], parse2['abstract'])
                doc.meta_confidence *= 0.9
            debug(1, "confidence reduced to %s", doc.meta_confidence)
        enrich_doc(doc, parse2)
    else:
        # This should never happen
        logger.warning('extractor failed on %s (ocr-ed), giving up', doc.url)
        os.remove(shortened_pdf)
        return True
    if not keep_tempfiles:
        os.remove(shortened_pdf)
        os.remove(shortened_xml)
    return True
    
def extractor(xmlfile):
    cmd = [PERL, join(path, 'Extractor.pm'), "-v{}".format(debuglevel()), xmlfile]
    debug(2, ' '.join(cmd))
    try:
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=60)
        output = output.decode('utf-8', 'ignore')
    except subprocess.CalledProcessError as e:
        debug(1, e.output)
        return False
    except subprocess.TimeoutExpired as e:
        debug(1, 'Extractor timeout!')
        return False
    json_separator = '=========== RESULT ===========\n'
    if not json_separator in output:
        debug(1, 'Extractor failed:\n%s', output)
        return False
    log,jsonstr = output.split(json_separator, 1)
    debug(1, log)
    res = json.loads(jsonstr)
    return res

def enrich_xml(xmlfile, doc):
    """
    add doc properties to xmlfile produced by htmltopdf (or ocr2xml)
    for processing by the Perl metadata extractor
    """
    def mk_el(tag, content):
        return '<{}>{}</{}>'.format(tag, content or '', tag)
    new_xml = '\n'.join([
        mk_el('url', doc.url),
        mk_el('anchortext', doc.link.anchortext),
        mk_el('linkcontext', doc.link.context),
        mk_el('sourceauthor', doc.source.default_author),
        mk_el('sourcecontent', doc.source.text())
        ])
    bakfile = xmlfile+'.bak'
    with open(bakfile, 'w') as fout:
        with open(xmlfile, 'r') as fin:
            for line in fin:
                fout.write(line)
                if '<pdf2xml' in line:
                    fout.write(new_xml+'\n')
    os.rename(bakfile, xmlfile)

def enrich_doc(doc, extractor_res, preserve_fields=None):
    if not preserve_fields:
        preserve_fields = []
    for k,v in extractor_res.items():
        if k not in preserve_fields:
            setattr(doc, k, v)
    doc.meta_confidence = int(100*float(extractor_res['meta_confidence']))

def strip_markup(string):
    '''strip <b>, <i>, <sub>, <sup> tags from extracted titles or abstractes'''
    return re.sub('</?.+?>', '', string)
