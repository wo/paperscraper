import re
import requests
import lxml.html
from lxml import etree
from lxml.html.clean import Cleaner
from nltk.tokenize import sent_tokenize
from opp.debug import debug

#
# Note (2015-09-11):
#
# There are several modules for extracting the main article content
# from websites. I've tried Goose, Readability, and Dragnet. None of
# them was really satisfactory. For example, on n-category cafe,
# Readability misses the intro part of posts, Goose removes all tags
# (including emphases), and all of them get the mathml formulas
# wrong. Moreover, none of the modules is able to extract the author
# name from posts on group blogs, and many fail to extract any content
# for blog posts without long blocks of text, such as
# https://philosophymodsquad.wordpress.com/2015/09/21/
#
# Rather than reinventing the wheel completely, what I do here is rely
# on Goose to identify the main post content (fall-back: rss feed
# content), locate that in the html source, and perform my own
# clean-up on the html; I also look for 'by [names]' strings in the
# vicinity of the start of the blog post to identify authors.
#
# Update 2016-06-13: Goose requires Python 2, so I'm currently always
# falling back on the rss feed content

def parse(doc):
    """
    tries to enrich doc by metadata (authors, title, abstract,
    numwords, content)
    """
    debug(3, "fetching blog post %s", doc.url)
    bytehtml = requests.get(doc.url).content.decode('utf-8', 'ignore')
    doc.content = extract_content(bytehtml, doc)
    doc.numwords = len(doc.content.split())
    doc.abstract = get_abstract(doc.content)
    debug(2, "\npost abstract: %s\n", doc.abstract)
    #if not doc.authors:
    #    doc.authors = get_authors(html, post_html, doc.content)
    #    debug(3, "\npost authors: %s\n", doc.authors)

def extract_content(bytehtml, doc):
    """
    extracts blog post content from html
    """
    lxmldoc = lxml.html.document_fromstring(bytehtml)
    cleaner = Cleaner()
    cleaner.scripts = True
    cleaner.comments = True
    cleaner.style = True
    #cleaner.page_structure = True
    cleaner.kill_tags = ['head', 'noscript']
    cleaner.remove_tags = ['p', 'i', 'b', 'strong', 'em']
    cleaner(lxmldoc)
    content_el = find_content_element(lxmldoc)
    text = content_el.text_content().strip()
    #print(text)
    return text
    
def find_content_element(el, best_el=None):
    """
    returns the descendent of el with the best text-to-html ratio and
    text length > MIN_LENGTH
    """ 
    MIN_LENGTH = 500
    for child in el:
        textlen = len(child.text_content())
        if textlen < MIN_LENGTH:
            continue
        htmllen = len(etree.tostring(child))
        child._ratio = textlen/htmllen
        if best_el is None or child._ratio > best_el._ratio:
            best_el = child
        best_child = find_content_element(child, best_el=best_el)
        if best_child != best_el:
            best_el = best_child
    return best_el

#bytehtml = b'<html><body><div>asdf hahaha</div><p>dddd</p></body></html>'
#doc = lxml.html.document_fromstring(bytehtml)
#print(find_content_element(doc))

def get_abstract(string):
    text = strip_tags(string, keep_italics=True)
    sentences = sent_tokenize(text[:1000])
    abstract = ''
    for sent in sentences:
        abstract += sent+' '
        if len(abstract) > 200:
            break
    return abstract

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
    


