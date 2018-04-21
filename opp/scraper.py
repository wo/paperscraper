#!/usr/bin/env python3
import time, re
from datetime import datetime, timedelta
import requests
from difflib import SequenceMatcher
import os.path
import subprocess
import shutil
import tempfile
import hashlib
from selenium.common.exceptions import *
from opp import db
from opp import error
from opp import util
from opp.models import Source, Link, Doc, categories
from opp.debug import debug
from opp.browser import Browser
from opp.webpage import Webpage
from opp.pdftools.pdftools import pdfinfo
from opp.pdftools.pdf2xml import pdf2xml
from opp.exceptions import *

def next_source():
    """return the next source from db that's due to be checked"""

    # First priority: process newly found pages so that we can better
    # decide whether they're genuine source pages or not.
    query = ("SELECT * FROM sources WHERE status = 0"
             " AND sourcetype != 'blog'"
             " AND last_checked IS NULL"
             " ORDER BY last_checked LIMIT 1")
    cur.execute(query)
    debug(4, cur._last_executed)
    sources = cur.fetchall()
    if sources:
        debug(1, "processing new source")
        return Source(**sources[0])
        # After processing, the source will have a last_checked date,
        # but still status=0, so it will not be processed again until
        # it is confirmed.
    
    # Second priority: process confirmed and working pages.
    min_age = datetime.now() - timedelta(hours=16)
    min_age = min_age.strftime('%Y-%m-%d %H:%M:%S')
    cur = db.dict_cursor()
    query = ("SELECT * FROM sources WHERE status = 1"
             " AND sourcetype != 'blog'"
             " AND (last_checked IS NULL OR last_checked < %s)"
             " ORDER BY last_checked LIMIT 1")
    cur.execute(query, (min_age,))
    debug(4, cur._last_executed)
    sources = cur.fetchall()
    if sources:
        return Source(**sources[0])

    # Third priority: occasionally re-test broken pages to decide
    # whether we should remove them for good. (Want to give
    # maintainers a few days to fix things.)
    min_age = datetime.now() - timedelta(hours=96)
    min_age = min_age.strftime('%Y-%m-%d %H:%M:%S')
    cur = db.dict_cursor()
    query = ("SELECT * FROM sources WHERE status > 1"
             " AND sourcetype != 'blog'"
             " AND (last_checked IS NULL OR last_checked < %s)"
             " ORDER BY last_checked LIMIT 1")
    cur.execute(query, (min_age,))
    debug(4, cur._last_executed)
    sources = cur.fetchall()
    if sources:
        debug(1, "re-checking broken source")
        return Source(**sources[0])

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
    
    (5) If a page is processed for the first time (no links yet
    associated with it), we don't want to display all linked papers in
    the news feed. Nonetheless, we process all links so that we can
    check for revisions (think of the Stanford Encyclopedia). To avoid
    displaying the papers as new, we mark them with a found_date of
    1970.
    """

    debug(1, '*'*50)
    debug(1, "checking links on %s", source.url)

    # go to page:
    browser = Browser(use_virtual_display=True)
    try:
        browser.goto(source.url)
    except Exception as e:
        debug(1, 'connection to source %s failed: %s', source.url, str(e))
        source.mark_as_dead(browser.status or error.code['connection failed'])
        return 0

    if browser.current_url != source.url:
        # redirects of journal pages are OK (e.g. from /current to
        # /nov-2015), but redirects of personal papers pages are often
        # caused by pages having disappeared; the redirect can then
        # take us e.g. to CMU's general document archive; we don't
        # want that. So here we wait for manual approval of the new
        # url, except if the new url is a trivial variant of the old
        # one, e.g. 'https' instead of 'http'.
        if source.sourcetype == 'personal':
            if trivial_url_variant(browser.current_url, source.url):
                source.update_db(url=browser.current_url)
            else:
                debug(1, '%s redirects to %s', source.url, browser.current_url)
                source.update_db(status=301)
                return 0
        else:
            debug(2, '%s redirected to %s', source.url, browser.current_url)

    # extract links:
    try:
        source.set_html(browser.page_source)
    except WebDriverException as e:
        debug(1, 'webdriver error retrieving page source: %s', e)
        source.update_db(status=error.code['cannot parse document'])
        return 0        

    source.extract_links(browser)
    
    # Selenium doesn't tell us when a site yields a 404, 401, 500
    # etc. error. But we can usually tell from the fact that there are
    # few known links on the error page:
    debug(1, 'old status {}, old links: {}'.format(source.status, len(source.old_links)))
    if source.last_checked and len(source.old_links) <= 1:
        debug(1, 'suspiciously few old links, checking status code')
        status, r = util.request_url(source.url)
        if status != 200:
            debug(1, 'error %s at source %s', status, source.url)
            source.mark_as_dead(status)
            return 0

    source.update_db(status=1)
    
    # process new links:
    if source.new_links:
        for li in source.new_links:
            debug(1, '*** processing new link to %s on %s ***', li.url, source.url)
            process_link(li)
            # for testing: one link only
            # return 1
    else:
        debug(1, "no new links")

    # re-process recently found old links that generated errors:
    for li in source.old_links:
        if li.status > 9:
            tdelta = datetime.now() - li.found_date
            if tdelta.days < 5:
                debug(1, 're-checking recent link %s on %s with status %s', 
                      li.url, source.url, li.status)
                process_link(li, force_reprocess=True)
    
    # re-check old links to papers for revisions:
    #MAX_REVCHECK = 3
    #goodlinks = (li for li in source.old_links if li.doc_id)
    #for li in sorted(goodlinks, key=lambda x:x.last_checked)[:MAX_REVCHECK]:
    #    debug(1, 're-checking old link to paper %s on %s for revisions', li.url, source.url)
    #    process_link(li)

    if not keep_tempfiles:
        remove_tempdir()

    # TODO: make process_link return 1/0 depending on whether link
    # leads to paper; then check here if there are no old links and no
    # new links to paper => mark as 404.


def process_link(li, force_reprocess=False, redir_url=None, keep_tempfiles=False,
                 recurse=0):
    """
    Fetch url, check for http errors and steppingstones, filter spam,
    parse candidate papers, check for duplicates, check if paper is old.

    Links often lead to intermediate pages (e.g. on repositories) with
    another link to the actual paper. In this case, we only store the
    original link in the 'links' table, so the 'doc' entry has a url
    that doesn't match any link. To process the new link, process_link
    is called again, with redir_url set to the new url and recurse +=
    1.

    If force_reprocess is False and the link has already been checked
    at some point, if_modified_since and etag headers are sent.
    """

    if not hasattr(li, 'context'): # skip context extraction on redirects
        try:
            li.context = li.html_context()
        except StaleElementReferenceException:
            debug(2, "link element has disappeared")
            return li.update_db(status=1, doc_id=None)
        debug(2, "link context: %s", li.context)
    
        # ignore links to old and published papers:
        if context_suggests_published(li.context):
            return li.update_db(status=1, doc_id=None)
    
    # fetch url and handle errors, redirects, etc.:
    url = redir_url or li.url
    r = li.fetch(url=url, only_if_modified=not(force_reprocess))
    # note: li.fetch() updates the link entry in case of errors
    if not r:
        debug(2, "failed to load %s", url)
        return 0
    
    if r.url != url: # redirected 
        # We generally ignore redirect urls and treat li as if it
        # directly led to the redirected address. Exception: if the
        # redirected address is unmanageably long, as on Barry Smith's
        # page.
        if len(r.url) < 500:
            url = util.normalize_url(r.url)

    if r.filetype not in ('html', 'pdf', 'doc', 'rtf'):
        li.update_db(status=error.code['unsupported filetype'])
        return debug(1, "unsupported filetype: %s", r.filetype)

    doc = Doc(url=url, r=r, link=li, source=li.source)

    old_id = doc.get_id()
    if old_id and not force_reprocess:
        li.update_db(status=1, doc_id=old_id)
        return debug(1, "%s is already in docs table", url)
    
    if r.filetype == 'html':
        r.encoding = 'utf-8'
        try:
            doc.page = Webpage(url, html=r.text)
        except UnparsableHTMLException:
            li.update_db(status=error.code['unsupported filetype'])
            return debug(1, "unparsable html")

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
        from .docparser import webpageparser as htmlparser
        if not htmlparser.parse(doc):
            debug(1, "page ignored")
            li.update_db(status=1)
            return 0

    else:
        try:
            (doc.tempfile, doc.filehash) = save_local(r)
        except:
            return li.update_db(status=error.code['cannot save local file'])
        # check if doc with that filehash already stored:
        old_id = doc.get_id()
        if old_id:
            debug(1, "document already stored under id %s", old_id)
            li.update_db(status=1, doc_id=old_id)
            return 0
        try:
            # metadata extraction:
            process_file(doc, keep_tempfiles=keep_tempfiles)
        except Exception as e:
            debug(1, 'could not process %s: %s', doc.tempfile, e)
            return li.update_db(status=error.code.get(str(e), 10))
    
    # estimate whether doc is a handout, cv etc.:
    from .doctyper import paperfilter
    paperprob = paperfilter.evaluate(doc)
    doc.is_paper = int(paperprob * 100)
    if doc.is_paper < 25:
        li.update_db(status=1)
        debug(1, "spam: paper score %s < 50", doc.is_paper)
        return 0
        
    # estimate whether doc is on philosophy:
    from .doctyper import classifier
    philosophyfilter = classifier.get_classifier('philosophy')
    try:
        doc.is_philosophy = int(philosophyfilter.classify(doc) * 100)
    except UntrainedClassifierException as e:
        doc.is_philosophy = 90
    if doc.is_philosophy < 25:
        li.update_db(status=1)
        debug(1, "spam: philosophy score %s < 50", doc.is_philosophy)
        return 0
        
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
            if not dupe.filehash:
                dupe.filehash = doc.filehash
                dupe.update_db()
            return 0
    
        # ignore old and published paper:
        if paper_is_old(doc):
            li.update_db(status=1, doc_id=None)
            debug(1, "ignoring already published paper")
            return 0

        # flag for manual approval if confidence low or dubious relevance:
        if doc.is_paper < 60 or doc.is_philosophy < 60 or doc.meta_confidence < 60:
            debug(1, "flagging for manual approval")
            doc.hidden = True

        # don't show papers (incl HTML pages) from newly added source
        # pages in news feed:
        debug(1, "source.last_checked: {}".format(li.source.last_checked)) # DEBUGGING!!!!!!!!!!!!!!!!!!!!!!!!!!!gg
        if not li.source.last_checked:
            debug(2, "new source page: setting found_date to 1970")
            doc.found_date = datetime(1970, 1, 1)
    
    # make sure doc fits in db:
    if len(doc.title) > 255:
        doc.title = doc.title[:251]+'...'
    if len(doc.authors) > 255:
        doc.authors = doc.authors[:251]+'...'
    
    doc.update_db()
    li.update_db(status=1, doc_id=doc.doc_id)

    # categorize, but only if doc has more than 1000 words --
    # otherwise categorization is pretty random:
    if doc.numwords > 700:
        for (cat_id, cat) in categories():
            clf = classifier.get_classifier(cat)
            try:
                strength = int(clf.classify(doc) * 100)
                debug(3, "%s score %s", cat, strength)
            except UntrainedClassifierException as e:
                continue 
            doc.assign_category(cat_id, strength)

    return 1

def process_file(doc, keep_tempfiles=False):
    """converts document to pdf, then xml, then extracts metadata"""
    
    if doc.filetype != 'pdf':
        # convert to pdf
        try:
            doc.tempfile = convert_to_pdf(doc.tempfile)
        except:
            raise Exception("pdf conversion failed")

    # get pdf info:
    try:
        pdfmeta = pdfinfo(doc.tempfile)
        doc.numpages = int(pdfmeta['Pages'])
    except:
        raise Exception('pdfinfo failed')
    debug(2, 'pdf has %s pages', doc.numpages)

    # convert to xml:
    doc.xmlfile = doc.tempfile.rsplit('.')[0] + '.xml'
    if doc.numpages > 10:
        # ocr only first 7 + last 3 pages if necessary:
        ocr_ranges = [(1,3), (doc.numpages-2,doc.numpages)]
    else:
        ocr_ranges = None
    try:
        engine = pdf2xml(doc.tempfile, doc.xmlfile, 
                         keep_tempfiles=keep_tempfiles,
                         ocr_ranges=ocr_ranges)
    except Exception as e:
        debug(1, "converting pdf to xml failed: %s", e)
        raise Exception('pdf conversion failed')

    # read some basic metadata from xml file: 
    doc.content = util.text_content(doc.xmlfile)
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
    from .doctyper import doctyper
    doc.doctype = doctyper.evaluate(doc)

    # extract metadata:
    from .docparser import paperparser
    if not paperparser.parse(doc, keep_tempfiles=keep_tempfiles):
        raise Exception('parser error')
        return 0


def check_steppingstone(page):
    """
    checks wether Webpage <page> is a cover page for a single paper,
    as repositories, journals etc. often have; if yes, returns the url
    of the actual paper.
    """

    debug(3, "checking: intermediate page leading to article?")

    # steppingstone pages from known repositories:
    redir_patterns = [
        # arxiv.org, springer.com, researchgate, etc.:
        (re.compile('<meta name="citation_pdf_url" content="(.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # philpapers.org:
        (re.compile('<h1.+ href="https://philpapers.org/go.pl[^"]+u=(http.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # philsci-archive.pitt.edu:
        (re.compile('<meta name="eprints.document_url" content="(.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # sciencedirect.com:
        (re.compile('pdfurl="(.+?)"'),
        (lambda m: page.make_absolute(requests.utils.unquote(m.group(1))))),
        # PLOSOne:
        (re.compile('(https?://www.plosone.org/article/.+?representation=PDF)" id="downloadPdf"'),
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
    
    # other steppingstone pages must have link(s) to a single pdf file
    # and not be an SEP entry:
    if 'stanford.edu/entries' in page.url:
        return None
    targets = set(u for u in page.xpath('//a/@href') if re.search('.pdf$', u, re.I))
    if len(targets) != 1:
        debug(3, "no: %s links to pdf files", len(targets))
        debug(4, "targets: %s", targets)
        return None
    target = targets.pop()
    debug(3, "yes: single link to pdf file %s", target)
    target = util.normalize_url(page.make_absolute(target))
    return target
    
def save_local(r):
    '''saves file from resource, returns (local_path, md5)'''
    # use recognizable tempfile name:
    m = re.search('/([^/]+?)(?:\.\w+)?(?:[\?\#].+)*$', r.url)
    fname = m.group(1) if m else r.url
    fname = re.sub('\W', '_', fname) + '.' + r.filetype
    temppath = os.path.join(tempdir(), fname)
    debug(2, "saving %s to %s", r.url, temppath)
    md5 = hashlib.md5()
    try:
        with open(temppath, 'wb') as f:
            for block in r.iter_content(1024):
                f.write(block)
                md5.update(block)
    except EnvironmentError as e:
        debug(1, "cannot save %s to %s: %s", r.url, temppath, str(e))
        raise
    return (temppath, md5.hexdigest())
    
def convert_to_pdf(tempfile):
    outfile = tempfile.rsplit('.',1)[0]+'.pdf'
    try:
        cmd = ['/usr/bin/python3', '/usr/bin/unoconv', 
               '-f', 'pdf', '-o', outfile, tempfile]
        debug(2, ' '.join(cmd))
        subprocess.check_call(cmd, timeout=20)
    except Exception as e:
        debug(1, "cannot convert %s to pdf: %s", tempfile, str(e))
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
    where = ['doc_id != %s']
    values = [doc.doc_id]
    m = re.search('\w+', doc.title) # first title word
    if m:
        where.append('title LIKE %s') 
        values.append('%'+m.group()+'%')
    m = re.search('(\w+)(?:,|$)', doc.authors) # first author surname
    if m:
        where.append('authors LIKE %s')
        values.append('%'+m.group(1)+'%')
    cur = db.dict_cursor()
    query = "SELECT * FROM docs WHERE " + (' AND '.join(where))
    cur.execute(query, values)
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

def trivial_url_variant(url1, url2):
    """
    returns True if the two urls are almost identical so that we don't
    have to manually approve a source page redirect.
    """
    # ignore trailing slashes:
    url1 = url1.rstrip('/')
    url2 = url2.rstrip('/')
    if url1.split(':',1)[1] == url2.split(':',1)[1]:
        # https vs http
        return True
    if url1.replace('www.', '') == url2.replace('www.', ''):
        # 'www.example.com' vs 'example.com'
        return True
    return False

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
    for m in re.finditer(r'\b\d{4}\b', context):
        if 1950 < int(m.group(0)) <= datetime.today().year:
            break
    else:
        debug(4, 'no suitable year in context suggests not yet published')
        return False

    # See https://github.com/wo/opp-tools/issues/54
    pubterms = [r'\beds?\b', r'edit(?:ed|ors?)', r'\d-+\d\d', r'\d:\s*\d', 'journal', r'philosophical\b']
    for t in pubterms:
        if re.search(t, context, re.I):
            debug(1, "ignoring published paper ('%s' in context)", t)
            return True
    debug(4, 'no publication keywords, assuming not yet published')
    return False

#def journal_names():
#    try:
#        return journal_names.res
#    except AttributeError:
#        cur = db.cursor()
#        cur.execute("SELECT name FROM journals")
#        journal_names.res = cur.fetchall()
#        return journal_names.res

def paper_is_old(doc):
    """
    check if document is old; currently we just check against our
    publications database (retrieved from philpapers) because google
    scholar includes citations for documents that aren't even
    available as drafts yet
    """
    debug(4, "checking if paper is old")
    title = re.sub('<[\S]+?>', '', doc.title) # strip tags
    cur = db.cursor()
    query = "SELECT author FROM publications WHERE title = %s"
    cur.execute(query, (title,))
    for row in cur.fetchall():
        if row[0] in doc.authors:
            # TODO: need to allow for fuzzy name matching!
            debug(2, "paper is in publications database; ignoring.")
            return True
    return False

    # TODO: remove or reactivate scholar lookup
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
    from . import scholar
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

