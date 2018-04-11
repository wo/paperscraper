#!/usr/bin/python3.4
import re
import time
from urllib.parse import quote_plus, parse_qs, urlparse
from urllib.request import Request, urlopen
from http.cookiejar import LWPCookieJar
from bs4 import BeautifulSoup
try:
    from .debug import debug, debuglevel
except SystemError:
    # command line usage
    import os.path
    import sys
    curpath = os.path.abspath(os.path.dirname(__file__))
    libpath = os.path.join(curpath, os.path.pardir)
    sys.path.insert(0, libpath)
    from opp.debug import debug, debuglevel

def search(query):
    """
    Search <query> on google
    """
    urls = []
    query = quote_plus(query)
    url = "https://www.google.de/search?q={}".format(query)
    debug(5, "fetching %s", url)
    html = get_page(url)
    #debug(5, "response:\n%s\n", html)
    soup = BeautifulSoup(html, 'html.parser')
    anchors = soup.find(id='search').findAll('a')
    for a in anchors:
        try:
            url = a['href']
        except KeyError:
            continue
        # skip google cache:
        if 'webcache' in url:
            continue
        # decode redirect URLs:
        parsed = urlparse(url)
        if url.startswith('/url'):
            query_params = parse_qs(parsed.query)
            urls.append(query_params['q'][0])
        elif url.startswith('http'):
            urls.append(url)
    return urls

def get_page(url):
    """
    Request the given URL and return the response page.

    If we pretend to be an ordinary browser, as util.request_url does,
    google returns an unparsable monstrosity of JS. We also need to
    set up cookies for google.
    """
    time.sleep(1)
    USER_AGENT = 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.0)'
    request = Request(url)
    request.add_header('User-Agent', USER_AGENT)
    cookie_jar = get_cookie_jar()
    cookie_jar.add_cookie_header(request)
    try:
        response = urlopen(request)
        cookie_jar.extract_cookies(response, request)
        html = response.read()
        response.close()
    except urllib.error.HTTPError as httperr:
        debug(1, httperr.headers)
        debug(httperr.read())
    cookie_jar.save()
    return html

def get_cookie_jar():
    """returns cookie jar"""
    COOKIE_JAR_FILE = '/home/wo/opp-tools/.googlesearch-cookie'
    cookie_jar = LWPCookieJar(COOKIE_JAR_FILE)
    cookie_jar.load()
    return cookie_jar

if __name__ == "__main__":

    # for testing and debugging
    import argparse
    import logging
    logger = logging.getLogger('opp')
    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG)
    logger.addHandler(ch)
    debuglevel(5)

    ap = argparse.ArgumentParser()
    ap.add_argument('query')
    args = ap.parse_args()

    urls = search(args.query)
    for url in urls:
        print(url)
        
