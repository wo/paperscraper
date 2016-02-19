#!/usr/bin/env python3
import requests
from lxml import html
from urllib.parse import urljoin
from difflib import SequenceMatcher
import time, sys, re
from datetime import datetime, timedelta
import logging
import logging.handlers
import os.path
import subprocess
import shutil
import json
import db
from browser import Browser
from webpage import Webpage
from config import config

"""
A script to find new papers. 

Main function: process_page(url)
"""

logger = logging.getLogger(__name__)

use_virtual_display = True
debug_level = 1
    
def debug(level, msg, *args):
    if debug_level >= level:
        logger.debug(msg, *args)


_browser = None
def browser():
    global _browser
    global use_virtual_display
    if not _browser:
        _browser = Browser(use_virtual_display=use_virtual_display)
    return _browser

def process_link(li, force_reprocess=False, redir_url=None, recurse=0):
    """
    fetch url, check for http errors and steppingstones, filter spam,
    save local file, convert to xml, add source_url etc. to xml,
    run Extractor on xml file, compute spam score, check for
    duplicate, check if published before last year.

    Links often lead to intermediate pages (e.g. on repositories) with
    another link to the actual paper. In this case, we only store the
    original link in the 'links' table, so the 'doc' entry has a url
    that doesn't match any link. To process the new link, process_link
    is called again, with redir_url set to the new url and recurse +=
    1.
    """
    
    # fetch url and handle errors, redirects, etc.:
    time.sleep(2) # be gentle on servers
    
    url = redir_url or li.url

    if not force_reprocess and li.last_checked:
        ims = time.strptime(li.last_checked, '%Y-%m-%d %H:%M:%S').strftime('%a, %d %b %Y %H:%M:%S GMT')
        status,r = self.request_url(url, if_modified_since=ims, etag=li.etag)
        if (status == 304 or
            status == 200 and r.headers.get('content-length') == li.filesize):
            li.update_db()
            debug(2, "not modified: not processing further")
            return 0
    else:
        status,r = self.request_url(url)
    
    if status != 200:
        li.update_db(status=status)
        debug(2, "error status {}", status)
        return 0

    li.etag = r.headers.get('etag')
    li.filsesize = r.headers.get('content-length')
    
    if r.url != url: # redirected
        url = self.normalize_url(r.url)
        # now we treat li as if it directly led to the redirected document

    if r.filetype == 'html':
        r.encoding = 'utf-8'
        doc = Webpage(url, html=r.text)
        debug(5, "\n====== %s ======\n%s\n======\n", url, r.text)

        # check for steppingstone pages with link to a paper:
        target_url = check_steppingstone(doc)
        if target_url and recurse < 3:
            debug(2, "steppingstone to {}", target_url)
            return process_link(li, redir_url=target_url, 
                                force_reprocess=force_reprocess, recurse=recurse+1)
        
        # Genuine papers are almost never in HTML format, and
        # almost every HTML page is not a paper. Moreover, the few
        # exceptions (such as entries on SEP) tend to require
        # unusual parsing. Hence the following special
        # treatment. If people start posting articles on medium or
        # in plain HTML, we might return to the old procedure of
        # converting the page to pdf and treating it like any
        # candidate paper.
        import parser.html
        if not parser.html.parse(doc, debug_level=debug_level):
            debug(2, "no metadata extracted: page ignored")
            li.update_db(status=1)
            return 0

    if r.filetype not in ('pdf', 'doc', 'rtf'):
        li.update_db(status=error.code['unsupported filetype')]
        return debug(2, "unsupported filetype: {}", r.filetype)

    else:
        doc = r
        doc.anchortext = li.anchortext
        doc.source = li.source

        # save document and convert to pdf:
        doc.tempfile = self.save_local(r)
        if not doc.tempfile:
            return li.update_db(status=error.code['cannot save local file')]
        if r.filetype != 'pdf':
            doc.tempfile = self.convert_to_pdf(doc.tempfile)
            if not doc.tempfile:
                return li.update_db(status=error.code['pdf conversion failed')]

        # extract metadata:
        import parser.pdf
        if not parser.pdf.parse(doc, debug_level=debug_level):
            logger.warning("metadata extraction failed for {}", url)
            li.update_db(status=error.code['parser error')]
            return 0

        # estimate spamminess:
        import spamfilter.pdf 
        doc.spamminess = spamfilter.pdf.evaluate(doc)
        if doc.spamminess > MAX_SPAMMINESS:
            li.update_db(status=1)
            debug(1, "spam: score {} > {}", doc.spamminess, self.MAX_SPAMMINESS)
            return 0

    if li.doc_id:
        # checking for revisions
        olddoc = Doc(li.doc_id)
        olddoc.load_from_db()
        if doc.content != olddoc.content:
            sm = SequenceMatcher(None, doc.content, olddoc.content)
            match_ratio = sm.ratio()
            if match_ratio < 0.8:
                debug(1, "substantive revisions, ratio {}", match_ratio)
                doc.earlier_id = olddoc.doc_id
        if not doc.earlier_id:
            li.update_db(status=1)
            debug(1, "no substantive revisions")
            return 0
    
    else:
        # check for duplicates:
        dupe = get_duplicate(doc)
        if dupe:
            debug(1, "duplicate of document {}", dupe.doc_id)
            li.update_db(status=1, doc_id=dupe.doc_id)
            return 0
    
        # don't show old papers in news feed:
        if document_is_old(doc):
            debug(2, "paper is old: setting found_date to 1970")
            doc.found_date = '1970-01-01 12:00:00'

        # don't show papers (incl HTML pages) from newly added source
        # pages in news feed:
        if source.status == 0:
            debug(2, "new source page: setting found_date to 1970")
            doc.found_date = '1970-01-01 12:00:00'
        
    doc_id = doc.add_to_db()
    li.update_db(status=1, doc_id)



                


    def check_steppingstone(self, page):
        debug(2, "checking: intermediate page leading to article?")

        # steppingstone pages from known repositories:
        redir_patterns = {
            # arxiv.org, springer.com, researchgate, etc.:
            '<meta name="citation_pdf_url" content="(.+?)"': '*',
            # philpapers.org:
            'class=\'outLink\' href="http://philpapers.org/go.pl[^"]+u=(http.+?)"': '*', 
            # philsci-archive.pitt.edu:
            '<meta name="eprints.document_url" content="(.+?)"': '*',
            # sciencedirect.com:
            'pdfurl="(.+?)"': '*',
            # PLOSOne:
            '(http://www.plosone.org/article/.+?representation=PDF)" id="downloadPdf"': '*',
            # Google Drive:
            'content="https://drive.google.com/file/d/(.+?)/': 'https://googledrive.com/host/*'
        }
        for pat, target in redir_patterns:
            m = re.search(pat, page.source)
            if m:
                target = target.replace('*', m.group(1))
                target = self.normalize_url(page.make_absolute(target))
                if target == page.url:
                    return None
                debug(2, "repository page for {}", target)
                return target
    
        # other steppingstone pages must have link(s) to a single pdf file:
        targets = set(u for u in page.xpath('//a/@href') if re.search('.pdf$', u, re.I))
        if len(targets) != 1:
            debug(4, "no: {} links to pdf files", len(targets))
            return None
        debug(4, "looks good: single link to pdf file {}", targets[0])
        target = self.normalize_url(page.make_absolute(targets[0]))
        return target
        
