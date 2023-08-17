#!/usr/bin/env python3
import re
import time
import requests
from lxml import html
from urllib.parse import urljoin
from opp import error

def normalize_url(url):
    url = url.split('#')[0]
    """normalize ~ vs %7e etc. and strip local anchors #foo"""
    return requests.utils.requote_uri(url)

def request_url(url, if_modified_since=None, etag=None, timeout=10, maxsize=10000000, maxredirects=5):
    """
    fetches url, returns (status, response_object), where
    response_object has an additional 'filetype' field
    """
    headers = {
        # Emulate a web browser profile:
        'user-agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:37.0) Gecko/20100101 Firefox/37.0',
        'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'accept-language': 'en-US,en;q=0.5'
    }
    if if_modified_since:
        headers['if-modified-since'] = if_modified_since
    if etag:
        headers['if-none-match'] = etag
    try:
        # using stream to respect maxsize and load timeouts, see
        # http://stackoverflow.com/questions/22346158/
        r = requests.get(url, headers=headers, timeout=timeout, stream=True)
        if int(r.headers.get('Content-Length', 0)) > maxsize:
            return 903, None
        size = 0
        start = time.time()
        content = b''
        for chunk in r.iter_content(1024):
            if time.time() - start > timeout:
                r.close()
                raise requests.exceptions.Timeout
            size += len(chunk)
            content += chunk
            if size > maxsize:
                r.close()
                return 903, None
        if r.status_code == 200:
            r._content = content
            r.filetype = request_filetype(r)
            if meta_redirect(r) and maxredirects > 0:
                return request_url(r.redirect_url,
                                   if_modified_since=if_modified_since,
                                   etag=etag,
                                   timeout=timeout,
                                   maxsize=maxsize,
                                   maxredirects=maxredirects-1)
        return r.status_code, r
    except requests.exceptions.Timeout:
        return 408, None
    except requests.exceptions.TooManyRedirects:
        return 902, None
    except requests.exceptions.RequestException as e:
        print('requests connection failed: {}'.format(e))
        return 905, None
    except Exception as e:
        print('uncaught requests exception: {}'.format(e))
        print(e)
        # raise?
        return 900, None

def request_filetype(r):
    def normalize(ft):
        ft = ft.lower()
        if ft in ('msword', 'docx'): return 'doc'
        if ft == 'htm': return 'html'
        if ft == 'text': return 'html'
        return ft
    # trust the following content-type headers:
    content_type = r.headers.get('content-type')
    m = re.search(r'pdf|rtf|msword|html?', content_type, re.I) 
    if m:
        return normalize(m.group(0))
    # for others, first check if content has pdf signature:
    if r.content.startswith(b'%PDF-'):
        return 'pdf'
    # otherwise use file-ending, if it is a 2-4 character string:
    m = re.search(r'/.+/.+\.([A-Za-z]{2,4})$', r.url)
    if m:
        return normalize(m.group(1))
    # otherwise just accept whatever the header says:
    m = re.search(r'.+/(.+)', content_type)
    if m: 
        return normalize(m.group(1))
    else:
        return 'unknown'

def meta_redirect(r):
    """read redirect url from meta tags"""
    if r.filetype == 'html':
        html_tree = html.fromstring(r.text)
        attrs = html_tree.xpath("//meta[translate(@http-equiv, 'REFSH', 'refsh') = 'refresh']/@content")
        if not attrs:
            return False
        wait, text = attrs[0].split(";")
        text = text.strip()
        if text.lower().startswith("url="):
            r.redirect_url = text[4:]
            if not r.redirect_url.startswith('http'):
                # Relative URL, adapt
                r.redirect_url = urljoin(r.url, r.redirect_url)
            return True
    return False

def get_http_status(url, timeout=10):
    """returns http status from <url>"""
    headers = {
        # Emulate a web browser profile:
        'user-agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:37.0) Gecko/20100101 Firefox/37.0',
        'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'accept-language': 'en-US,en;q=0.5'
    }
    try:
        # using stream to respect maxsize and load timeouts, see
        # http://stackoverflow.com/questions/22346158/
        r = requests.get(url, headers=headers, timeout=timeout, stream=True)
        r.close()
        return r.status_code
    except requests.exceptions.Timeout:
        return 408
    except requests.exceptions.TooManyRedirects:
        return 902
    except requests.exceptions.ConnectionError:
        return 905
    except Exception as e:
        print('uncaught requests exception: {}'.format(e))
        return 905

def strip_tags(text, keep_italics=False):
    # simplistic function to strip tags from tagsoup and possibly keep
    # italics
    if keep_italics:
        text = re.sub(r'<(/?)(?:i|b|em)>', r'{\1emph}', text, flags=re.IGNORECASE)
        # also keep sub/supscript tags, e.g. for 'x_1'
        text = re.sub(r'<(/?su[bp])>', r'{\1}', text, flags=re.IGNORECASE)
    text = re.sub(r'<script.+?</script>', '', text, flags=re.DOTALL|re.IGNORECASE)
    text = re.sub(r'<style.+?</style>', '', text, flags=re.DOTALL|re.IGNORECASE)
    text = re.sub(r'<.+?>', ' ', text, flags=re.DOTALL)
    text = re.sub(r'<', '&lt;', text)
    text = re.sub(r'  +', ' ', text)
    text = re.sub(r'(?<=\w) (?=[\.,;:\-\)])', '', text)
    if keep_italics:
        text = re.sub(r'{(/?)emph}', r'<\1i>', text)
        text = re.sub(r'{(/?su[bp])}', r'<\1>', text)
    return text

def text_content(xmlfile):
    '''
    return sanitized paper content from pdf2xml output: xml tags
    stripped, words broken ataround line-ends joined.
    '''
    with open(xmlfile, 'r', encoding='utf-8') as f:
        xml = f.read()
        text = ''
        textre = re.compile(r'<text.+?>(.+?)</text>', re.DOTALL)
        for m in textre.finditer(xml):
            text += m.group(1) + '\n'
        # strip <sub>, <b>, etc.:
        text = re.sub(r'</?\w.*?>', '', text)
        # join hyphenated words:
        text = re.sub(r'[-—]\n(\w\S+)\s', r'\1\n', text)
        return text
