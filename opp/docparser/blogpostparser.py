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

import re
import requests
#from goose import Goose
from nltk.tokenize import sent_tokenize
from ..debug import debug

# To install nltk.tokenize:
# pip install nltk
# python
#    import nltk
#    nltk.import('punkt')
# sudo mv ~/nltk_data /usr/lib/

def parse(doc):
    """
    tries to enrich doc by metadata (authors, title, abstract,
    numwords, content)
    """
    debug(3, "fetching blog post %s", doc.url)
    html = requests.get(doc.url).content.decode('utf-8', 'ignore')
    #goose = Goose()
    #article = goose.extract(raw_html=html)
    #goose_text = article.cleaned_text
    #debug(5, "\ngoose text: %s\n", goose_text)
    #if not goose_text:
    #    debug(3, "goose-extract failed, using feed content")
    #    goose_text = strip_tags(feed_content)
    #post_html = match_text_in_html(goose_text, html)
    #post_html = match_text_in_html(strip_tags(doc.content), html)
    #if post_html:
    #    doc.content = strip_tags(post_html)
    #    debug(5, "\npost content: %s\n", doc.content)
    doc.content = strip_tags(doc.content, keep_italics=True)
    doc.numwords = len(doc.content.split())
    doc.abstract = get_abstract(doc.content)
    debug(3, "\npost abstract: %s\n", doc.abstract)
    #if not doc.authors:
    #    doc.authors = get_authors(html, post_html, doc.content)
    #    debug(3, "\npost authors: %s\n", doc.authors)

def match_text_in_html(text, html):
    """
    returns html fragment in <html> whose plain text content is <text>
    """
    # avoid matches e.g. in <meta name="description" content="blah blah">):
    html = re.sub(r'^.+<body[^>]+>', '', html, flags=re.DOTALL|re.IGNORECASE)
    start_words = re.findall(r'\b\w+\b', text[:50])[:-1]
    re_str = r'\b.+?\b'.join(start_words)
    m1 = shortest_match(re_str, html)
    if not m1:
        return debug(4, "%s not found in html: %s", re_str, html)
    debug(5, "best match for start words %s at: %d", re_str, m1.start(1))
    end_words = re.findall(r'\b\w+\b', text[-50:])[1:]
    re_str = r'\b.+?\b'.join(end_words)
    m2 = shortest_match(re_str, html)
    if not m2:
        return debug(4, "%s not found in html: %s", re_str, html)
    debug(5, "best match for end words %s at: %d", re_str, m2.end(1))
    return html[m1.start(1):m2.end(1)]

def shortest_match(re_str, string):
    """
    returns shortest match of <re_str> in <string>
    """
    # lookahead to get all matches, including overlapping ones:
    regex = re.compile('(?=({}))'.format(re_str), re.DOTALL)
    ret = None
    for m in regex.finditer(string):
        if not ret or len(m.group(1)) < len(ret.group(1)):
            ret = m
    return ret

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

def get_abstract(html):
    text = strip_tags(html, keep_italics=True)
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
    


