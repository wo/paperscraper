#!/usr/bin/env python3
import re
from collections import defaultdict
from urllib.parse import urljoin
import lxml.html
import lxml.etree
from lxml.html.clean import Cleaner
from functools import lru_cache

class Webpage():

    def __init__(self, url, html=None):
        self.url = url
        self.html = html
        self._lxmldoc = None
        self._text = None
        self._base_href = None
        self._session_vars = None
   
    def lxmldoc(self, cache=True):
        """returns lxml representation of the page"""
        if cache and self._lxmldoc is not None:
            return self._lxmldoc
        # self.html is a python unicode string, not e.g. a utf-8
        # bytestring; so if the html code contains an encoding
        # declaration, that declaration will be a lie, which makes
        # lxml's document_fromstring complain. So here's an ugly hack
        # to strip the encoding declaration.
        html_undeclared = self.html.replace('encoding=', 'gnidocne=')
        self._lxmldoc = lxml.html.document_fromstring(html_undeclared)
        return self._lxmldoc
 
    def xpath(self, xp):
        return self.lxmldoc().xpath(xp)

    def text(self):
        """returns plain text content"""
        if self._text is None:
            # need new copy of lxmldoc because Cleaner modifies it:
            doc = self.lxmldoc(cache=False)
            Cleaner(kill_tags=['noscript'], style=True)(doc)
            self._text = " ".join(lxml.etree.XPath("//text()")(doc))
        return self._text

    def base_href(self):
        """returns base url for relative links"""
        if self._base_href is None:
            base = self.xpath('//head/base/@href')
            if base:
                self._base_href = base[0]
            else:
                self._base_href = self.url
        return self._base_href

    def make_absolute(self, href):
        """turn relative into absolute links"""
        return urljoin(self.base_href(), href)

    def session_variables(self):
        """return set of possible session variables in links"""
        if self._session_vars is None:
            # start with default list:
            self._session_vars = {'session', 'session_id', 'jsessionid', 's_id', 'halsid', 'wpnonce', 'locale'}
            # add url parameters common to many links:
            hrefs = self.xpath('//a/@href')
            count_params = defaultdict(int)
            for m in re.finditer('([\w_-]+)=', ' '.join(hrefs)):
                count_params[m.group(1)] += 1
            self._session_vars |= set(p for p,i in count_params.items() if i>2)
        return self._session_vars
        
    @lru_cache() # memoize
    def strip_session_variables(self, url):
        if not hasattr(self, '_svarpat'):
            svars = self.session_variables()
            self._svarpat = re.compile('(?:'+('|'.join(svars))+')=[\w-]+')
        return self._svarpat.sub('', url)
