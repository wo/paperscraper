#!/usr/bin/env python3
import re
from lxml import etree
from nltk.tokenize import sent_tokenize
from ..debug import debug

def parse(doc):
    """
    tries to enrich doc by metadata (authors, title, abstract,
    numwords, doctype, content); returns True if successful, False if
    doc.page doesn't look like an article.
    """
    page = doc.page
    debug(2, "parsing page %s", page.url)
    
    if 'stanford.edu/entries' not in page.url:
        debug(2, "page is not a Stanford Encyclopedia entry")
        return False

    # title:
    h1s = page.xpath('//h1/text()')
    if not h1s:
        debug(2, "page is not a Stanford Encyclopedia entry")
        return False
    doc.title = h1s[0]
    
    # abstract:
    preamble_divs = page.xpath("//div[@id='preamble']")
    if not preamble_divs:
        debug(2, "page is not a Stanford Encyclopedia entry")
        return False
    preamble_html = etree.tostring(preamble_divs[0], encoding='unicode')
    doc.abstract = get_abstract(preamble_html)

    # authors:
    copyright_divs = page.xpath("//div[@id='article-copyright']")
    if not copyright_divs:
        debug(2, "page is not a Stanford Encyclopedia entry")
        return False
    copyright_html = etree.tostring(copyright_divs[0], encoding='unicode')
    copyright_html = re.sub('<a.+Copyright.+', '', copyright_html)
    copyright_html = re.sub('&lt;.+?&gt;', '', copyright_html)
    authors = [strip_tags(frag).strip() for frag in copyright_html.split('<br/>')]
    doc.authors = ', '.join([a for a in authors if a])

    # text content:
    #textnodes = page.xpath("//div[@id='article-content']//text()")
    #if not textnodes:
    #    debug(2, "page is not a Stanford Encyclopedia entry")
    #    return False
    #doc.content = ' '.join([n.strip() for n in textnodes if n.strip()])

    doc.content = page.text()
    doc.numwords = len(doc.content.split())
    doc.numpages = int(doc.numwords/300) # rough guess, just for classifiers
    doc.doctype = 'article'
    doc.meta_confidence = 90

    return True

def strip_tags(text, keep_italics=False):
    if keep_italics:
        text = re.sub(r'<(/?)(?:i|b|em)>', r'{\1emph}', text, flags=re.IGNORECASE)
        # also keep sub/supscript tags, e.g. for 'x_1'
        text = re.sub(r'<(/?su[bp])>', r'{\1}', text, flags=re.IGNORECASE)
    text = re.sub('<script.+?</script>', '', text, flags=re.DOTALL|re.IGNORECASE)
    text = re.sub('<style.+?</style>', '', text, flags=re.DOTALL|re.IGNORECASE)
    text = re.sub('<.+?>', ' ', text, flags=re.DOTALL)
    text = re.sub('<', '&lt;', text)
    text = re.sub('  +', ' ', text)
    text = re.sub('(?<=\w) (?=[\.,;:\-\)])', '', text)
    if keep_italics:
        text = re.sub(r'{(/?)emph}', r'<\1i>', text)
        text = re.sub(r'{(/?su[bp])}', r'<\1>', text)
    return text

def get_abstract(html, max_len=1000):
    text = strip_tags(html, keep_italics=True).strip()
    sentences = sent_tokenize(text[:1000])
    abstract = ''
    for sent in sentences:
        abstract += sent+' '
        if len(abstract) > 600:
            break
    return abstract.strip()
