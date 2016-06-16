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
    fixes title and content of blogpost <doc> and adds authors,
    abstract, numwords
    """
    debug(3, "fetching blog post %s", doc.url)
    bytehtml = requests.get(doc.url).content.decode('utf-8', 'ignore')
    try:
        doc.content = extract_content(bytehtml, doc) or strip_tags(doc.content)
    except:
        pass
    doc.numwords = len(doc.content.split())
    doc.abstract = get_abstract(doc.content)
    if doc.title.isupper():
        doc.title = doc.title.capitalize()
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
    cleaner.remove_tags = ['p', 'i', 'b', 'strong', 'em', 'blockquote']
    cleaner(lxmldoc)
    content_el = find_content_element(lxmldoc)
    if content_el:
        debug(3, 'content quality {}'.format(content_el._quality))
        text = content_el.text_content().strip()
        return text
    else:
        debug(2, 'no content found!')
        return ''
    
def find_content_element(el, best_el=None):
    """
    returns the descendent of el with the best combination of
    text-to-html ratio and text length
    """ 
    for child in el:
        MIN_LENGTH = 200
        child._textlen = len(child.text_content())
        if child._textlen < MIN_LENGTH:
            continue
        child._quality = quality(child)
        if child._quality > 0 and (not best_el or child._quality > best_el._quality):
            best_el = child
        best_child = find_content_element(child, best_el=best_el)
        if best_child != best_el:
            best_el = best_child
    return best_el
    
def quality(el):
    """
    gives a numerical score to <el> measuring its plausibility as blog
    post content, weighing text-to-html ratio and text length
    """
    textlen = el._textlen
    htmllen = len(etree.tostring(el))
    ratio = textlen/htmllen
    # A blog post often contains lengthy paragraphs without any tags
    # and thus perfect textlen/htmllen ratio; we still want to prefer
    # larger elements with decent ratio. Roughly, if we can add 500
    # characters (~1 paragraph) of text with 100 characters of tags,
    # we should do that. The following equation approximates what we
    # might want: quality = ratio^3 * textlen
    quality = (ratio**3)*textlen
    print(etree.tostring(el)[:100])
    print("textlen {}, htmllen {}, ratio {}, quality {}".format(textlen, htmllen, ratio, quality))
    if quality < 300:
        return  0
    return quality

#bytehtml = b'<html><body><div>asdf hahaha</div><p>dddd</p></body></html>'
#doc = lxml.html.document_fromstring(bytehtml)
#print(find_content_element(doc))

def get_abstract(text):
    sentences = sent_tokenize(text[:1000])
    abstract = ''
    for sent in sentences:
        abstract += sent+' '
        if len(abstract) > 200:
            break
    return abstract+'&hellip;'

def strip_tags(text, keep_italics=False):
    """
    strip tags from <text> but possibly keep emphasis tags
    """
    if keep_italics:
        text = re.sub(r'<(/?)(?:i|b|em|strong)>', r'{\1emph}', text, flags=re.IGNORECASE)
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
    


