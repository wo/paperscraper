import re
import requests
import lxml.html
from lxml import etree
from lxml.html.clean import Cleaner
from nltk.tokenize import sent_tokenize
import trafilatura
from opp.debug import debug

def parse(doc):
    """
    main method: fixes title and content of blogpost <doc> and adds
    authors, abstract, numwords
    """
    debug(3, "fetching blog post %s", doc.url)

    html = trafilatura.fetch_url(doc.url)
    doc.content = extract_content(html)
    doc.numwords = len(doc.content.split())
    doc.abstract = get_abstract(doc.content)
    if doc.title.isupper():
        doc.title = doc.title.capitalize()
    trafilatura.reset_caches()
    debug(2, "\npost abstract: %s\n", doc.abstract)
    #if not doc.authors:
    #    doc.authors = get_authors(html, post_html, doc.content)
    #    debug(3, "\npost authors: %s\n", doc.authors)


def get_abstract(text):
    sentences = sent_tokenize(text[:1000])
    abstract = ''
    for sent in sentences:
        abstract += sent+' '
        if len(abstract) > 200:
            break
    return abstract+'&hellip;'

def extract_content(html):
    content = trafilatura.extract(html, include_comments=False)
    if not content:
        debug(2, "no content found in blogpost")
        return ''
    content = strip_headers(content, html)
    content = strip_footers(content, html)
    return content

def strip_headers(content, html):
    """
    remove title, dates, "written by...", etc. from <content> (string)
    """
    stripped = content
    while '\n' in stripped:
        line, rem  = stripped.split('\n', 1)
        # check if line is short and occurs in its own element in the html:
        if len(line) < 30 and re.search(r'<[^>]*>'+re.escape(line)+r'</[^>]*>', html):
            stripped = rem
            continue
        # check if line is a heading:
        if re.search(r'<h\d[^>]*>'+re.escape(line)+r'</h\d>', html):
            stripped = rem
            continue
        # check if <title> element contains line:
        m = re.search(r'<title>([^<]+)</title>', html, re.IGNORECASE)
        if m and line in m.group(1):
            stripped = rem
            continue
        if re.match(r'^(?:written|posted) by(?: \S+){1,4}$', line, re.IGNORECASE):
            stripped = rem
            continue
        return stripped
    return stripped

def strip_footers(content, html):
    """
    remove "Leave a reply" etc. from <content> (string)
    """
    stripped = content
    while '\n' in stripped:
        line = content.split('\n')[-1]
        if re.match(r'^\s*(?:leave ?a? reply|leave ?a? comment|reply)', line, re.IGNORECASE):
            stripped = '\n'.join(content.split('\n')[:-1])
            continue
        if re.match(r'^(?:written|posted) by(?: \S+){1,4}$', line, re.IGNORECASE):
            stripped = '\n'.join(content.split('\n')[:-1])
            continue
        # check if line is short and occurs in its own element in the html:
        if len(line) < 30 and re.search(r'<[^>]*>'+re.escape(line)+r'</[^>]*>', html):
            stripped = '\n'.join(content.split('\n')[:-1])
            continue
        return stripped
    return stripped
    
def get_authors(full_html, post_html, post_text):
    # look for 'by (Foo Bar)' near the start of the post
    post_start = full_html.find(post_html)
    tagsoup = r'(?:<[^>]+>|\s)*'
    by = r'[Bb]y\b'+tagsoup
    name = r'[\w\.\-]+(?: (?!and)[\w\.\-]+){0,3}'
    separator = tagsoup+r'(?: and |, )'+tagsoup
    re_str = r'{}({})(?:{}({}))*'.format(by,name,separator,name)
    regex = re.compile(re_str)
    best_match = None
    for m in regex.finditer(full_html):
        if post_text.find(m.group(1)) > 20:
            debug(2, 'author candidate "%s" because too far in text', m.group(1))
            continue
        if not best_match or abs(m.start()-post_start) < abs(best_match.start()-post_start):
            best_match = m
    if best_match:
        names = [n for n in best_match.groups() if n]
        return ', '.join(names)
    return ''
    


