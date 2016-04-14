#!/usr/bin/env python3
import time, sys, re
from datetime import datetime, timedelta
import requests
from lxml import html
from difflib import SequenceMatcher
import statistics
import logging
import os.path
import subprocess
import shutil
import tempfile
import db
import error
import util
from debug import debug, debuglevel
from browser import Browser
from webpage import Webpage
from pdftools.pdftools import pdfinfo, pdfcut
from pdftools.pdf2xml import pdf2xml
from config import config
from exceptions import *

logger = logging.getLogger('opp')

def next_source():
    """return the next source from db that's due to be checked"""
    min_age = datetime.now() - timedelta(hours=12)
    min_age = min_age.strftime('%Y-%m-%d %H:%M:%S')
    cur = db.dict_cursor()
    query = ("SELECT * FROM sources WHERE"
             " sourcetype != 'blog'" # ignore rss feeds
             " AND (last_checked IS NULL OR last_checked < %s)"
             " ORDER BY last_checked LIMIT 1")
    cur.execute(query, (min_age,))
    debug(4, cur._last_executed)
    sources = cur.fetchall()
    if sources:
        return Source(**sources[0])
    else:
        debug(1, "all pages recently checked")
        return None

def scrape(source, keep_tempfiles=False):
    """
    Look for new papers linked to on the source page (and check for
    revisions to known papers).     

    Issues to keep in mind:
    
    (1) Links on personal pages often lead to old papers that have
    been published long ago. (That's true even for newly added links,
    when people upload older papers.) We don't want to list these
    papers in the news feed, nor do we need to check them for
    revisions. So if we find a link to an old and published paper, we
    treat it like a link to a non-paper. (If a manuscript changes into
    a published paper, we keep the paper in the database because it
    still ought to show up as "new papers found on x/y/z" and because
    it might have been used to train personal filters, but we remove
    the doc_id from the link, thereby marking the link as known but
    irrelevant.)

    (2) Sometimes links to papers are temporarily broken, or
    there's a temporary problem with the metadata extraction. So
    if we encounter an error while processing a (promising) new
    link, we try again once or twice in the course of the next
    week (using link.found_date).

    (3) To check for revisions of existing manuscripts (and, more
    unusually, new papers appearing at an old url), we have to
    occasionally re-process known links. But we don't want to re-parse
    all documents all the time. Instead, we select a few old papers
    (i.e., links with an associated doc_id that are still on the page,
    ordered by last_checked).

    (4) We could remove all links from the db that are no longer on
    the page, but it's probably not worth the effort. Moreover, pages
    are sometimes temporarily replaced by "under maintanance" pages
    (for example), and then we may not want to re-process all links
    once the page comes back. So we simply ignore disappeared links:
    they remain in the db, but they are never revisited until they
    reappear on the page.
    
    (5) If a page is processed for the first time (status==0 in the
    db), we don't want to display all linked papers in the news
    feed. Nonetheless, we process all links so that we can check for
    revisions (think of the Stanford Encyclopedia). To avoid
    displaying the papers as new, we mark them with a found_date of
    1970.
    """

    debug(1, "checking links on %s", source.url)

    # go to page:
    browser = Browser(use_virtual_display=True)
    try:
        browser.goto(source.url)
    except Exception as e:
        logger.warning('connection to source %s failed: %s', source.url, str(e))
        source.update_db(status=error.code['connection failed'])
        return 0

    if browser.current_url != source.url:
        # redirects of journal pages are OK (e.g. from /current to
        # /nov-2015), but redirects of personal papers pages are often
        # caused by pages having disappeared; the redirect can then
        # take us e.g. to CMU's general document archive; we don't
        # want that. So here we wait for manual approval of the new
        # url.
        if source.sourcetype == 'personal':
            logger.warning('%s redirects to %s', source.url, browser.current_url)
            source.update_db(status=301)
            return 0
        else:
            debug(2, '%s redirected to %s', source.url, browser.current_url)

    # look for new links:
    source.set_html(browser.page_source)
    new_links = {} # url => Link
    old_links = {} # url => Link
    for li in browser.find_elements_by_tag_name("a"):
        if not li.is_displayed() or not li.get_attribute('href'):
            continue
        href = li.get_attribute('href')
        if is_bad_url(href):
            debug(3, 'ignoring link to %s (bad url)', href)
            continue
        href = util.normalize_url(source.make_absolute(href))
        old_link = source.old_link(href)
        if old_link:
            debug(3, 'link to %s is old: %s', href, old_link.url)
            old_links[href] = old_link
            old_links[href].element = li
        else:
            debug(1, 'new link: "%s" %s', li.text, href)
            new_links[href] = Link(url=href, source=source, element=li)
    
    # Selenium doesn't tell us when a site yields a 404, 401, 500
    # etc. error. But we can usually tell from the fact that there are
    # few known links on the error page:
    debug(1, 'status {}, old links: {}'.format(source.status, len(old_links.keys())))
    if source.status > 0 and len(old_links.keys()) <= 1:
        debug(1, 'suspiciously few old links, checking status code')
        status, r = util.request_url(source.url)
        if status != 200:
            logger.warning('error %s at source %s', status, source.url)
            source.update_db(status=status)
            return 0

    source.update_db(status=1)
    
    # process new links:
    if new_links:
        for li in new_links.values():
            debug(1, '\nprocessing new link to %s', li.url)
            process_link(li)
            # for testing: one link only
            # return 1
    else:
        debug(1, "no new links")

    # re-process recently found old links that generated errors:
    for li in old_links.values():
        if li.status > 9:
            tdelta = datetime.now() - li.found_date
            if tdelta.days < 5:
                debug(1, 're-checking recent link %s with status %s', li.url, li.status)
                process_link(li, force_reprocess=True)
    
    # re-check old links to papers for revisions:
    MAX_REVCHECK = 3
    goodlinks = [li for li in old_links.values() if li.doc_id]
    for li in sorted(goodlinks, key=lambda x:x.last_checked)[:MAX_REVCHECK]:
        debug(1, 're-checking old link to paper %s for revisions', li.url)
        process_link(li)

    if not keep_tempfiles:
        remove_tempdir()

    # TODO: make process_link return 1/0 depending on whether link
    # leads to paper; then check here if there are no old links and no
    # new links to paper => mark as 404.


def process_link (li, force_reprocess=False, redir_url=None, keep_tempfiles=False,
                 recurse=0):
    """
    Fetch url, check for http errors and steppingstones, filter spam,
    parse candidate papers, check for duplicates, check if published
    before last year.

    Links often lead to intermediate pages (e.g. on repositories) with
    another link to the actual paper. In this case, we only store the
    original link in the 'links' table, so the 'doc' entry has a url
    that doesn't match any link. To process the new link, process_link
    is called again, with redir_url set to the new url and recurse +=
    1.

    If force_reprocess is False and the link has already been checked
    at some point, if_modified_since and etag headers are sent.
    """

    # ignore links to old and published papers:
    li.context = li.html_context()
    debug(2, "link context: %s", li.context)
    if context_suggests_published(li.context):
        li.update_db(status=1, doc_id=None)
        return 0
    
    # fetch url and handle errors, redirects, etc.:
    url = redir_url or li.url
    r = li.fetch(url=url, only_if_modified=not(force_reprocess))
    if not r: 
        return 0
        
    if r.url != url: # redirected
        url = util.normalize_url(r.url)
        # now we treat li as if it directly led to the redirected document

    if r.filetype not in ('html', 'pdf', 'doc', 'rtf'):
        li.update_db(status=error.code['unsupported filetype'])
        return debug(1, "unsupported filetype: %s", r.filetype)

    doc = Doc(url=url, r=r, link=li, source=li.source)
    
    if r.filetype == 'html':
        r.encoding = 'utf-8'
        doc.page = Webpage(url, html=r.text)
        debug(6, "\n====== %s ======\n%s\n======\n", url, r.text)

        # check for steppingstone pages with link to a paper:
        target_url = check_steppingstone(doc.page)
        if target_url and recurse < 3:
            debug(1, "steppingstone to %s", target_url)
            return process_link(li, redir_url=target_url, 
                                force_reprocess=force_reprocess, recurse=recurse+1)

        # Genuine papers are almost never in HTML format, and almost
        # every HTML page is not a paper. The few exceptions (such as
        # entries on SEP) tend to require special parsing. Hence the
        # following special treatment. If people start posting
        # articles on medium or in plain HTML, we might return to the
        # old procedure of converting the page to pdf and treating it
        # like any candidate paper.
        doc.content = doc.page.text()
        doc.numwords = len(doc.content.split())
        doc.numpages = 1
        import docparser.webpageparser as htmlparser
        if not htmlparser.parse(doc):
            debug(1, "page ignored")
            li.update_db(status=1)
            return 0

    else:
        # save as pdf:
        try:
            doc.tempfile = save_local(r)
        except:
            return li.update_db(status=error.code['cannot save local file'])
        if r.filetype != 'pdf':
            try:
                doc.tempfile = convert_to_pdf(doc.tempfile)
            except:
                debug(1, 'pdf conversion failed!')
                return li.update_db(status=error.code['pdf conversion failed'])
        try:
            pdfmeta = pdfinfo(doc.tempfile)
            doc.numpages = int(pdfmeta['Pages'])
        except:
            debug(1, 'pdfinfo failed!')
            return li.update_db(status=error.code['pdfinfo failed'])
        debug(2, 'pdf has %s pages', doc.numpages)

        # convert to xml:
        doc.xmlfile = doc.tempfile.rsplit('.')[0] + '.xml'
        if doc.numpages > 10:
            # ocr only first 7 + last 3 pages if necessary:
            ocr_ranges = [(1,7), (doc.numpages-2,doc.numpages)]
        else:
            ocr_ranges = None
        try:
            engine = pdf2xml(doc.tempfile, doc.xmlfile, 
                             keep_tempfiles=keep_tempfiles,
                             ocr_ranges=ocr_ranges)
        except Exception as e:
            debug(1, "converting pdf to xml failed: %s", e)
            return li.update_db(status=error.code['pdf conversion failed'])
        doc.content = util.strip_xml(readfile(doc.xmlfile))
        debug(5, "text content:\n%s", doc.content)
        if engine == 'pdftohtml':
            doc.numwords = len(doc.content.split())
        else:
            doc.ocr = True
            if doc.numpages > 10:
                # extrapolate numwords from numpages and the number of words
                # on the ocr'ed pages:
                doc.numwords = len(doc.content.split()) * doc.numpages/10
            else:
                doc.numwords = len(doc.content.split())

        # guess doc type (paper, book, review, etc.):
        import doctyper.doctyper as doctyper
        doc.doctype = doctyper.evaluate(doc)

        # extract metadata:
        import docparser.paperparser as paperparser
        if not paperparser.parse(doc, keep_tempfiles=keep_tempfiles):
            logger.warning("metadata extraction failed for %s", url)
            li.update_db(status=error.code['parser error'])
            return 0
            
        # estimate whether doc is not a handout, cv etc.:
        import doctyper.paperfilter as paperfilter
        paperprob = paperfilter.evaluate(doc)
        doc.is_paper = int(paperprob * 100)
        if doc.is_paper < 50:
            li.update_db(status=1)
            debug(1, "spam: paper score %s < 50", doc.is_paper)
            return 0
        
        # estimate whether doc is on philosophy:
        import doctyper.philosophyfilter as philosophyfilter
        try:
            philprob = philosophyfilter.evaluate(doc)
        except UntrainedClassifierException as e:
            philprob = 0.9
        doc.is_philosophy = int(philprob * 100)        
        if doc.is_philosophy < 50:
            li.update_db(status=1)
            debug(1, "spam: philosophy score %s < 50", doc.is_philosophy)
            return 0

        # TODO: classify for main topics?
            
    if li.doc_id:
        # check for revisions:
        olddoc = Doc(doc_id=li.doc_id)
        olddoc.load_from_db()
        if doc.content != olddoc.content:
            sm = SequenceMatcher(None, doc.content, olddoc.content)
            match_ratio = sm.ratio()
            if match_ratio < 0.8:
                debug(1, "substantive revisions, ratio %s", match_ratio)
                doc.earlier_id = olddoc.doc_id
        if not doc.earlier_id:
            li.update_db(status=1)
            debug(1, "no substantive revisions")
            return 0
    
    else:
        # check for duplicates:
        dupe = get_duplicate(doc)
        if dupe:
            debug(1, "duplicate of document %s", dupe.doc_id)
            li.update_db(status=1, doc_id=dupe.doc_id)
            return 0
    
        # ignore old and published paper:
        if paper_is_old(doc):
            li.update_db(status=1, doc_id=None)
            debug(1, "ignoring already published paper")
            return 0

        # don't show papers (incl HTML pages) from newly added source
        # pages in news feed:
        if doc.source.status == 0:
            debug(2, "new source page: setting found_date to 1970")
            doc.found_date = '1970-01-01 12:00:00'
        
    doc.update_db()
    li.update_db(status=1, doc_id=doc.doc_id)


class Source(Webpage):
    """ represents a source page with links to papers """
    
    db_fields = {
        'source_id': 0,
        'url': '',
        'sourcetype': 'personal', # (alt: repository, journal, blog)
        'status': 0, # 0 = unprocessed, 1 = OK, >1 = error
        'found_date': None,
        'last_checked': None,
        'default_author': '',
        'name': '' # e.g. "Australasian Journal of Logic"
    }

    def __init__(self, **kwargs):
        super().__init__(kwargs.get('url',''))
        for k,v in self.db_fields.items():
            setattr(self, k, kwargs.get(k, v))

    def load_from_db(self, url=''):
        url = url or self.url
        if not url:
            raise TypeError("need source url to load Source from db")
        cur = db.dict_cursor()
        query = "SELECT * FROM sources WHERE urlhash = MD5(%s)"
        cur.execute(query, (url,))
        debug(5, cur._last_executed)
        sources = cur.fetchall()
        if sources:
            for k,v in sources[0].items():
                setattr(self, k, v)
        else:
            debug(4, "%s not in sources table", url)
            
    def update_db(self, **kwargs):
        """write **kwargs to db, also update 'last_checked'"""
        if self.source_id:
            cur = db.cursor()
            kwargs['last_checked'] = time.strftime('%Y-%m-%d %H:%M:%S') 
            query = "UPDATE sources SET urlhash=MD5(url),{} WHERE source_id = %s".format(
                ",".join(k+"=%s" for k in kwargs.keys()))
            cur.execute(query, tuple(kwargs.values()) + (self.source_id,))
            debug(3, cur._last_executed)
            db.commit()
    
    def save_to_db(self):
        """write object to db"""
        cur = db.cursor()
        fields = [f for f in self.db_fields.keys()
                  if f != 'link_id' and getattr(self, f) != None]
        values = [getattr(self, f) for f in fields]
        query = "INSERT INTO sources ({}, urlhash) VALUES ({}, MD5(url))".format(
            ",".join(fields), ",".join(("%s",)*len(fields)))
        cur.execute(query, values)
        debug(3, cur._last_executed)
        db.commit()
        self.source_id = cur.lastrowid
    
    def set_html(self, html):
        debug(6, "\n====== %s ======\n%s\n======\n", self.url, html)
        self.html = html
    
    def old_link(self, url):
        """
        If a link to (a session variant of) url is already known on this
        page (as stored in the database), returns the stored Link,
        otherwise returns None.
        """
        if not hasattr(self, '_links'):
            cur = db.dict_cursor()
            query = "SELECT * FROM links WHERE source_id = %s"
            cur.execute(query, (self.source_id,))
            debug(5, cur._last_executed)
            self._links = [ Link(source=self, **li) for li in cur.fetchall() ]

        for li in self._links:
            if li.url == url:
                return li

        s_url = self.strip_session_variables(url)
        if s_url != url:
            for li in self._links:
                if s_url == self.strip_session_variables(li.url):
                    return li

        return None

        # We could also look for session variants in the whole db:
        # pattern = re.sub('(?<='+v+')[\w-]+', '[\\w-]+', url)
        # query = "SELECT url FROM links WHERE url REGEX %s LIMIT 1"
        # cur.execute(query, pattern)
        # variants = cur.fetchall()

class Link():
    """ represents a link on a source page """

    db_fields = {
        'link_id': 0,
        'url': '',
        'source_id': 0,
        'status': 0, # 0 = unprocessed, 1 = OK, >1 = error
        'found_date': None,
        'last_checked': None,
        'etag': None,
        'filesize': None,
        'doc_id': None
    }

    def __init__(self, **kwargs):
        for k,v in self.db_fields.items():
            setattr(self, k, kwargs.get(k, v))
        self.source = kwargs.get('source')
        self.element = kwargs.get('element') # the dom element from Browser
        if self.source:
            self.source_id = self.source.source_id
    
    def html_context(self):
        """
        sets self.anchortext and self.context, where the latter is the
        surrounding text of a link, often containing author, title,
        publication info; returns self.context
        
        There are three main cases:

        (1) The context we're looking for coincides with the content
            of a single DOM element (e.g. the <a> itself, or a <li>),
            possibly minus an abstract, which we can remove
            afterwards.

        (2) The context we're looking for coincides with the content
            of several DOM elements taken together
            (e.g. "<h4>Title</h4> <div>Forthcoming
            <a>Penultimate</a></div>"), possibly minus an abstract.

        (3) The context we're looking for is part of a DOM element
            that also contains contexts for other entries. E.g.,
            "<a>Paper1</a> Forthcoming<br> <a>Paper2</a>", or
            "<h4>Paper1</h4> Forthcoming <a>PDF</a> <h4>Paper2</h4>
            <a>PDF</a>", or "<h4><a>Paper1</a></h4> Forthcoming
            <h4><a>Paper2</a></h4>".

        To tell these apart, we first climb up the DOM tree until we
        reach an element that's too large to be a single paper entry
        (careful of abstracts here). If the element right below (call
        it el) has no further text than the link with which we started
        but there's neighbouring text not in a link, we assume we're
        in case (3); here we crudely divide el's parent by <br> or
        <h*> and return the content of the part surrounding el. To
        tell apart (1) and (2), we use some heuristics to determine
        whether el's context extends to its siblings: e.g., is there a
        gap between el and sibling? does the sibling also contain a
        link to a paper? etc.
        """

        if not self.element:
            raise Exception("need link element to extract html_context")
        self.anchortext = self.element.get_attribute('textContent').strip()
        debug(5, 'trying to find link context')

        # First climb up DOM until we reach an element (par) that's
        # too large:
        el = self.element
        par = el.find_element_by_xpath('..')
        debug(5, 'starting with %s', el.get_attribute('outerHTML'))
        el._text = el.get_attribute('textContent')
        while (True):
            debug(5, 'climbing up par: %s', par.get_attribute('outerHTML'))
            # check if parent has many links or other children
            par._links = par.find_elements_by_xpath('.//a')
            par._children = par.find_elements_by_xpath('./*')
            if len(par._links) > 3 or len(par._children) > 5:
                debug(5, 'stopping: too many links or children')
                break
            # List of drafts may only contain two papers, so we also
            # check if the previous element was already fairly
            # large. (We'll still treat such lists as a single context
            # if the entries are very short, but then that's not a
            # serious problem because we won't be misled by
            # publication info that belongs to another entry.)
            par._text = par.get_attribute('textContent')
            if len(el._text) > 70 and len(par._text) > len(el._text)*1.5:
                debug(5, 'stopping: enough text already (%s)', el._text)
                break
            try:
                gpar = par.find_element_by_xpath('..')
                el,par = par,gpar
            except Exception:
                break
        
        # If el has no further text than the link with which we
        # started but there's neighbouring text not in a link, we're
        # in the messy case (3):
        if len(el._text) - len(self.element._text) < 5:
            par._outerHTML = par.get_attribute('outerHTML')
            el._outerHTML = el.get_attribute('outerHTML')
            l,r = par._outerHTML.split(el._outerHTML, 2)
            if re.search(r'\w\s*$', l) or re.search(r'^\s*\w', r):
                debug(5, 'argh: case (3)')
                for pat in (r'<h\d.*?>', r'<br>\s*<br>', r'<br>'):
                    parts = re.split(pat, par._outerHTML, flags=re.I)
                    if len(parts) > 1:
                        break
                for part in parts:
                    if el._outerHTML in part:
                        debug(5, 'surrounding part: %s', part)
                        return util.strip_tags(part)
                # we should never be here
                return el._text
        
        # Now try to figure out if siblings belong to context:
        def context_left(i):
            if par._children.index(el)-i < 0:
                # can't catch IndexError: careful of negative indices!
                return ''
            lsib = par._children[par._children.index(el)-i]
            lsib_outerHTML = lsib.get_attribute('outerHTML')
            debug(5, "add left sibling?: %s", lsib_outerHTML)
            if re.search(r'\.(?:pdf|docx?)\b', lsib_outerHTML, flags=re.I):
                debug(5, "no: contains link to pdf or doc")
                return ''
            lsib_height = int(lsib.get_attribute('offsetHeight'))
            lsib_text = lsib.get_attribute('textContent')
            if lsib_text.strip() == '' and lsib_height > 2:
                debug(5, "no: sibling has no text but takes up space")
                return ''
            lsib_bottom = lsib.location['y'] + lsib_height
            gap = par._children[par._children.index(el)-(i-1)].location['y'] - lsib_bottom
            if gap > 20 or (gap > 10 and len(context) > 20):
                debug(5, "no: too far away (%s)", gap)
                return ''
            debug(5, "yes, expanding context")
            return lsib_text

        def context_right(i):
            try:
                rsib = par._children[par._children.index(el)+i]
            except IndexError:
                return ''
            rsib_outerHTML = rsib.get_attribute('outerHTML')
            debug(5, "add right sibling?: %s", rsib_outerHTML)
            if re.search(r'\.(?:pdf|docx?)\b', rsib_outerHTML, flags=re.I):
                debug(5, "no: contains link to pdf or doc")
                return ''
            if (len(context) > 20 
                and not re.search(r'\d{4}|draft|forthcoming', rsib_outerHTML, flags=re.I)):
                # We're mainly interested in author, title,
                # publication info. The first two never occur after
                # the link element (unless that is very short: e.g. an
                # icon), so we only need to check for the third.
                debug(5, "no: doesn't look like publication info")
                return ''
            rsib_height = int(rsib.get_attribute('offsetHeight'))
            rsib_text = rsib.get_attribute('textContent')
            if rsib_text.strip() == '' and rsib_height > 2:
                debug(5, "no: sibling has no text but takes up space")
                return ''
            rsiblsib = par._children[par._children.index(el)+(i-1)]
            rsiblsib_bottom = rsiblsib.location['y'] + int(rsiblsib.get_attribute('offsetHeight'))
            gap = rsib.location['y'] - rsiblsib_bottom
            if gap > 20 or (gap > 10 and len(context) > 20):
                debug(5, "no: too far away (%s)", gap)
                return ''
            debug(5, "yes, expanding context")
            return rsib_text

        context = el.get_attribute('textContent')
        debug(5, "initial context: %s", context)
        for i in (1,2,3):
            more = context_right(i)
            if not more: break
            context += '\n' + more
        for i in (1,2,3,4):
            more = context_left(i)
            if not more: break
            context = more + '\n' + context
        # tidy up slightly (mainly for easier testing):
        self.context = re.sub(r'\s*\n+\s*', r'\n', context).strip()
        return self.context

    def load_from_db(self, url='', source_id=0):
        url = url or self.url
        source_id = source_id or self.source_id
        if not url or not source_id:
            raise TypeError("need url and source_id to load Link from db")
        
        cur = db.dict_cursor()
        query = "SELECT * FROM links WHERE urlhash = MD5(%s) AND source_id = %s LIMIT 1"
        cur.execute(query, (url, source_id))
        debug(5, cur._last_executed)
        links = cur.fetchall()
        if links:
            for k,v in links[0].items():
                setattr(self, k, v)
        else:
            debug(4, "link to %s not in database", url)
    
    def update_db(self, **kwargs):
        """
        update self.**kwargs and write present state to db, also set
        'last_checked'
        """
        for k,v in kwargs.items():
            setattr(self, k, v)
        cur = db.cursor()
        self.last_checked = time.strftime('%Y-%m-%d %H:%M:%S')
        fields = [f for f in self.db_fields.keys()
                  if f != 'link_id' and getattr(self, f) != None]
        values = [getattr(self, f) for f in fields]
        if self.link_id:
            query = "UPDATE links SET {},urlhash=MD5(url) WHERE link_id = %s".format(
                ",".join(k+"=%s" for k in fields))
            cur.execute(query, values + [self.link_id])
        else:
            query = "INSERT INTO links ({},urlhash) VALUES ({},MD5(url))".format(
                ",".join(fields), ",".join(("%s",)*len(fields)))
            cur.execute(query, values)
            self.link_id = cur.lastrowid
        debug(3, cur._last_executed)
        db.commit()

    def fetch(self, url=None, only_if_modified=True):
        '''
        fetch linked document (or url), returns response object on
        success, otherwise stores error in db and returns None.
        '''
        time.sleep(1) # be gentle on servers
        url = url or self.url
        if only_if_modified and self.last_checked:
            ims = self.last_checked.strftime('%a, %d %b %Y %H:%M:%S GMT')
            status,r = util.request_url(url, if_modified_since=ims, etag=self.etag)
            if (status == 304 or
                status == 200 and r.headers.get('content-length') == self.filesize):
                self.update_db()
                debug(1, "not modified")
            return None
        else:
            status,r = util.request_url(url)
        if status != 200:
            self.update_db(status=status)
            debug(1, "error status %s", status)
            return None
        self.etag = r.headers.get('etag')
        self.filesize = r.headers.get('content-length')
        return r

class Doc():
    """ represents a paper """

    db_fields = {
        'doc_id': 0,
        'url': '',
        'doctype': 'article',
        'status': 1,
        'filetype': None,
        'filesize': 0,
        'found_date': None,
        'earlier_id': None,
        'authors': '',
        'title': '',
        'abstract': '',
        'numwords': 0,
        'numpages': 0,
        'source_url': '',
        'source_name': '',
        'meta_confidence': 0, # 0-100
        'is_paper': 0, # 0-100
        'is_philosophy': 0, # 0-100
        'content': ''
    }

    def __init__(self, **kwargs):
        for k,v in self.db_fields.items():
            setattr(self, k, kwargs.get(k, v))
        self.r = kwargs.get('r', None)
        if self.r:
            self.filetype = kwargs.get('filetype', self.r.filetype)
        self.link = kwargs.get('link', None)
        if self.link:
            self.filesize = kwargs.get('filesize', self.link.filesize)
        self.source = kwargs.get('source', self.link.source if self.link else None)
        if self.source:
            self.source_url = kwargs.get('source_url', self.source.url)
            self.source_name = kwargs.get('source_name', self.source.name)
        self.ocr = False
    
    def load_from_db(self, doc_id=0, url=''):
        doc_id = doc_id or self.doc_id
        url = url or self.url
        cur = db.dict_cursor()
        if doc_id:
            query = "SELECT * FROM docs WHERE doc_id = %s"
            cur.execute(query, (doc_id,))
        elif url:
            query = "SELECT * FROM docs WHERE urlhash = MD5(%s)"
            cur.execute(query, (url,))
        else:
            raise TypeError("need doc_id or url to load doc from db")
        debug(5, cur._last_executed)
        docs = cur.fetchall()
        if docs:
            for k,v in docs[0].items():
                setattr(self, k, v)
        else:
            debug(4, "no doc with id %s in database", doc_id)

    def update_db(self, **kwargs):
        """update self.**kwargs and write present state to db"""
        for k, v in kwargs.items():
            setattr(self, k, v)
        cur = db.cursor()
        fields = [f for f in self.db_fields.keys()
                  if f != 'doc_id' and getattr(self, f) != None]
        values = [getattr(self, f) for f in fields]
        if self.doc_id:
            query = "UPDATE docs SET {},urlhash=MD5(url) WHERE doc_id = %s".format(
                ",".join(k+"=%s" for k in fields))
            cur.execute(query, values + [self.doc_id])
        else:
            query = "INSERT INTO docs ({},urlhash) VALUES ({},MD5(url))".format(
                ",".join(fields), ",".join(("%s",)*len(fields)))
            cur.execute(query, values)
            self.doc_id = cur.lastrowid
        debug(4, cur._last_executed)
        db.commit()

def is_bad_url(url):
    re_bad_url = re.compile("""
                ^\#|
                ^mailto|
                ^data|
                ^javascript|
                ^.+//[^/]+/?$|          # TLD
                twitter\.com|
                fonts\.googleapis\.com|
                philpapers\.org/asearch|
                \.(?:css|mp3|avi|mov|jpg|gif|ppt|png|ico|mso|xml)(?:\?.+)?$   # .css?version=12
                """, re.I | re.X)
    return re_bad_url.search(url) is not None

def check_steppingstone(page):
    debug(3, "checking: intermediate page leading to article?")

    # steppingstone pages from known repositories:
    redir_patterns = [
        # arxiv.org, springer.com, researchgate, etc.:
        (re.compile('<meta name="citation_pdf_url" content="(.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # philpapers.org:
        (re.compile('class=\'outLink\' href="http://philpapers.org/go.pl[^"]+u=(http.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # philsci-archive.pitt.edu:
        (re.compile('<meta name="eprints.document_url" content="(.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # sciencedirect.com:
        (re.compile('pdfurl="(.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # PLOSOne:
        (re.compile('(http://www.plosone.org/article/.+?representation=PDF)" id="downloadPdf"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # Google Drive:
        (re.compile('content="https://drive.google.com/file/d/(.+?)/'),
        (lambda m: 'https://googledrive.com/host/{}'.format(requests.utils.unquote(m.group(1)))))
    ]
    for (pattern, retr_target) in redir_patterns:
        m = pattern.search(page.html)
        if m:
            target = util.normalize_url(retr_target(m))
            if target == page.url:
                return None
            debug(3, "yes: repository page for %s", target)
            return target
    
    # other steppingstone pages must have link(s) to a single pdf file:
    targets = set(u for u in page.xpath('//a/@href') if re.search('.pdf$', u, re.I))
    if len(targets) != 1:
        debug(3, "no: %s links to pdf files", len(targets))
        return None
    debug(3, "yes: single link to pdf file %s", targets[0])
    target = util.normalize_url(page.make_absolute(targets[0]))
    return target
    
def save_local(r):
    # use recognizable tempfile name:
    m = re.search('/([^/]+?)(?:\.\w+)?(?:[\?\#].+)*$', r.url)
    fname = m.group(1) if m else r.url
    fname = re.sub('\W', '_', fname) + '.' + r.filetype
    tempfile = os.path.join(tempdir(), fname)
    debug(2, "saving %s to %s", r.url, tempfile)
    try:
        with open(tempfile, 'wb') as f:
            for block in r.iter_content(1024):
                f.write(block)
    except EnvironmentError as e:
        logger.warning("cannot save %s to %s: %s", r.url, tempfile, str(e))
        raise
    return tempfile
    
def convert_to_pdf(tempfile):
    outfile = tempfile.rsplit('.',1)[0]+'.pdf'
    try:
        cmd = ['/usr/bin/python3', '/usr/bin/unoconv', 
               '-f', 'pdf', '-o', outfile, tempfile],
        debug(2, ' '.join(cmd))
        subprocess.check_call(cmd, timeout=20)
    except Exception as e:
        logger.warning("cannot convert %s to pdf: %s", tempfile, str(e))
        raise
    return outfile

def tempdir():
    if not hasattr(tempdir, 'dirname'):
        tempdir.dirname = tempfile.mkdtemp()
        debug(2, "creating temporary directory: %s", tempdir.dirname)
    return tempdir.dirname

def remove_tempdir():
    if hasattr(tempdir, 'dirname'):
        shutil.rmtree(tempdir.dirname)
        del tempdir.dirname

def readfile(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()
        
def get_duplicate(doc):
    """
    returns a document from db that closely resembles doc, or None
    """
    # This is non-trivial because duplicates can have slightly
    # different titles (e.g. with and without <i>), different
    # filesize and wordcount (manuscript vs published version),
    # different authors and abstracts (due to parser mistakes,
    # author name variants, etc.).
    debug(5, "checking for duplicates")
    titlefrag = re.sub('(\w+)', r'\1', doc.title) # first title word
    authorfrag = re.sub('(\w+)(?:,|$)', r'\1', doc.authors) # first author surname
    cur = db.dict_cursor()
    query = ("SELECT * FROM docs WHERE doc_id != %s "
             "AND title LIKE %s and authors LIKE %s")
    cur.execute(query, (doc.doc_id, '%'+titlefrag+'%', '%'+authorfrag+'%'))
    debug(5, cur._last_executed)
    dupes = cur.fetchall()
    for dupe in dupes:
        debug(5, "candidate: %s, '%s'", dupe['authors'], dupe['title'])
        if abs(doc.numwords - dupe['numwords']) / doc.numwords > 0.2:
            debug(5, "length not close enough")
            continue
        sm = SequenceMatcher(None, doc.content, dupe['content'])
        match_ratio = sm.ratio()
        if match_ratio < 0.1: # sic
            debug(5, "content too different, ratio %s", match_ratio)
            continue
        debug(4, "duplicate: %s, '%s'", dupe['authors'], dupe['title'])
        return Doc(**dupe)
    return None
    
def context_suggests_published(context):
    """
    returns True if the link context makes it fairly certain that the
    linked document has already been published before this year.
    """
    
    # uncomment to test paper processing:
    # return False

    if re.search('forthcoming|unpublished', context, re.I):
        debug(4, 'forthcoming/unpublished in context suggests not yet published')
        return False
    m = re.search(r'\b(\d{4})\b', context)
    year = m and int(m.group(1))
    if not year or year < 1950 or year >= datetime.today().year:
        debug(4, 'no suitable year in context suggests not yet published')
        return False

    # See https://github.com/wo/opp-tools/issues/54
    pubterms = [r'\beds?\b', r'edited', r'\d-+\d\d', r'\d:\s*\d', 'journal', r'philosophical\b']
    for t in pubterms:
        if re.search(t, context, re.I):
            debug(1, "ignoring paper published in %s ('%s' in context)", year, t)
            return True
    debug(4, 'no publication keywords, assuming not yet published')
    return False

def paper_is_old(doc):
    """
    checks online if document has been published earlier than this
    year
    """
    debug(4, "checking if paper is old")
    title = re.sub('<[\S]+?>', '', doc.title) # strip tags
    match = scholarquery(doc.authors, title)
    if (match and match['year'] 
        and 1950 < int(match['year']) < datetime.today().year-2):
        # Unfortunately, Google Scholar gives publication dates even
        # for unpublished manuscripts e.g. if they were cited with a
        # certain date once; so we only ignore papers if the given
        # date is at least two years old. TODO: improve! (If I finally
        # upload my "Generalizing Kripke Semantics" paper, I don't
        # want it to be treated as published in 2011!)
        debug(1, "paper already published in %s", match['year'])
        return True
    return False

def scholarquery(author, title):
    """ TODO: check if we're locked out of google scholar."""
    import scholar
    time.sleep(1)
    scholar.ScholarConf.COOKIE_JAR_FILE = os.path.join(tempdir(), 'scholar.cookie')
    querier = scholar.ScholarQuerier()
    settings = scholar.ScholarSettings()
    querier.apply_settings(settings)
    query = scholar.SearchScholarQuery()
    query.set_author(author)
    query.set_phrase(title)
    #before_year = 2016
    #query.set_timeframe(options.after, options.before)
    query.set_include_patents(False)
    querier.send_query(query)
    debug(4, 'google scholar query %s', query) 
    articles = querier.articles
    for a in articles:
        debug(4, 'result: %s (%s)', a['title'], a['year'])
        # Testing for exact equality of titles means that false
        # negatives are likely. On the other hand, we don't want to
        # treat "Desire as Belief II" as old just because there has
        # been "Desire as Belief". We err on the side of false
        # negatives:
        if a['title'].lower() == title.lower():
            return a
    return None

