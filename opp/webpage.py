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
    
    def xpath(self, xp):
        if self._lxmldoc is None:
            self._lxmldoc = lxml.html.document_fromstring(self.html)
        return self._lxmldoc.xpath(xp)

    def text(self):
        """returns plain text content"""
        if self._text is None:
            # need copy of _lxmldoc because Cleaner modifies it:
            doc = lxml.html.document_fromstring(self.html)
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
        """return list of possible session variables in links"""
        if self._session_vars is None:
            # start with default list:
            self._session_vars = ['session', 'session_id', 's_id', 'halsid', 'wpnonce', 'locale']
            # add url parameters common to many links:
            hrefs = self.xpath('//a/@href')
            count_params = defaultdict(int)
            for m in re.finditer('([\w_-]+)=', ' '.join(hrefs)):
                count_params[m.group(1)] += 1
            self._session_vars += [p for p,i in count_params if i>2]
        return self._session_vars
        
    @lru_cache() # memoize
    def strip_session_variables(self, url):
        if not hasattr(self, '_svarpat'):
            svars = self.session_variables()
            self._svarpat = re.compile('(?:'+('|'.join(svars))+')=[\w-]+')
        return self._svarpat.sub('', url)
