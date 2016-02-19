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

import logging
import re
from requests import get
from goose import Goose
from nltk.tokenize import sent_tokenize
# To install nltk.tokenize:
# pip install nltk
# python
#    import nltk
#    nltk.import('punkt')
# sudo mv ~/nltk_data /usr/lib/

logger = logging.getLogger(__name__)

def parse(url, feed_content):
    logger.debug("parsing blog post {}".format(url))
    html = get(url).content
    #logger.debug("\nsite html: %s\n", html)
    html = html.decode('utf-8', 'ignore')
    goose = Goose()
    article = goose.extract(raw_html=html)
    goose_text = article.cleaned_text
    logger.debug("\ngoose text: %s\n", goose_text)
    if not goose_text:
        logger.info("goose-extract failed, using feed content")
        goose_text = strip_tags(feed_content)
    post_html = match_text_in_html(goose_text, html)
    doc = {}
    doc['content'] = strip_tags(post_html)
    logger.debug("\npost content: %s\n", doc['content'])
    doc['numwords'] = len(doc['content'].split())
    doc['abstract'] = get_abstract(post_html)
    logger.debug("\npost abstract: %s\n", doc['abstract'])
    doc['authors'] = get_authors(html, post_html, doc['content'])
    logger.debug("\npost authors: %s\n", doc['authors'])
    return doc

def match_text_in_html(text, html):
    # avoid matches e.g. in <meta name="description" content="blah blah">):
    html = re.sub(r'^.+<body[^>]+>', '', html, flags=re.DOTALL|re.IGNORECASE)
    start_words = re.findall(r'\b\w+\b', text[:50])[:-1]
    re_str = r'\b.+?\b'.join(start_words)
    m1 = shortest_match(re_str, html)
    if not m1:
        logger.warning(u"%s not found in html: %s", re_str, html)
    logger.debug(u"best match for start words %s at: %d", re_str, m1.start(1))
    end_words = re.findall(r'\b\w+\b', text[-50:])[1:]
    re_str = r'\b.+?\b'.join(end_words)
    m2 = shortest_match(re_str, html)
    if not m2:
        logger.warning(u"%s not found in html: %s", re_str, html)
    logger.debug(u"best match for end words %s at: %d", re_str, m2.end(1))
    #print m2.end(1)
    return html[m1.start(1):m2.end(1)]

def shortest_match(re_str, string):
    # lookahead to get all matches, including overlapping ones:
    regex = re.compile('(?=({}))'.format(re_str), re.DOTALL)
    ret = None
    for m in regex.finditer(string):
        #print '\nmatch: {}\n\n'.format(m.group(1))
        if not ret or len(m.group(1)) < len(ret.group(1)):
            ret = m
    #print '\nshortest match: {}\n\n'.format(ret.group(1))
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
        if len(abstract) > 600:
            break
    return abstract

def get_authors(full_html, post_html, post_text):
    # look for 'by (Foo Bar)' near the start of the post
    post_start = full_html.find(post_html)
    #print "post_start: {}".format(post_start)
    tagsoup = r'(?:<[^>]+>|\s)*'
    by = r'[Bb]y\b'+tagsoup
    name = r'[\w\.\-]+(?: (?!and)[\w\.\-]+){0,3}'
    separator = tagsoup+r'(?: and |, )'+tagsoup
    re_str = r'{}({})(?:{}({}))*'.format(by,name,separator,name)
    regex = re.compile(re_str)
    #print "looking for {} in {}".format(re_str, full_html)
    best_match = None
    for m in regex.finditer(full_html):
        #print "{} matches {}".format(re_str, m.group(0))
        #print "({} vs {})".format(m.start(), post_start)
        # avoid matching "Sadly, so-and-so has been rejected by /British MPs/":
        if post_text.find(m.group(1)) > 20:
            logger.debug('author candidate "%s" because too far in text', m.group(1))
            continue
        if not best_match or abs(m.start()-post_start) < abs(best_match.start()-post_start):
            #print "best match ({} vs {})".format(m.start(), post_start)
            best_match = m
    if best_match:
        names = [n for n in best_match.groups() if n]
        #print ', '.join(names)
        return ', '.join(names)
    return ''
    
#url = 'http://blog.practicalethics.ox.ac.uk/2015/09/the-moral-limitations-of-in-vitro-meat/'
#url = 'https://golem.ph.utexas.edu/category/2015/08/wrangling_generators_for_subob.html'
#parse(url)


