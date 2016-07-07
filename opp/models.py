#!/usr/bin/env python3
import time, re
from datetime import datetime
from opp import db
from opp import error
from opp import util
from opp.debug import debug
from opp.webpage import Webpage

class Source(Webpage):
    """ represents a source page with links to papers """
    
    db_fields = {
        'source_id': 0,
        'url': '',
        'sourcetype': 'personal', # (alt: repo, journal, blog)
        'status': 0, # 0 = unprocessed, 1 = OK, >1 = error
        'found_date': None,
        'last_checked': None,
        'default_author': '',
        'name': '' # e.g. "Australasian Journal of Logic"
    }

    def __init__(self, **kwargs):
        super().__init__(kwargs.get('url',''), html=kwargs.get('html',''))
        for k,v in self.db_fields.items():
            setattr(self, k, kwargs.get(k, v))
        if not self.found_date:
            self.found_date = datetime.now()

    def load_from_db(self, url=''):
        url = url or self.url
        if not url:
            raise TypeError("need source url to load Source from db")
        cur = db.dict_cursor()
        query = "SELECT * FROM sources WHERE urlhash = MD5(%s)"
        cur.execute(query, (url,))
        debug(5, cur._last_executed)
        sources = cur.fetchall()
        if sources:
            for k,v in sources[0].items():
                setattr(self, k, v)
        else:
            debug(4, "%s not in sources table", url)
            
    def update_db(self, **kwargs):
        """write **kwargs to db, also update 'last_checked'"""
        if self.source_id:
            cur = db.cursor()
            kwargs['last_checked'] = time.strftime('%Y-%m-%d %H:%M:%S') 
            query = "UPDATE sources SET {},urlhash=MD5(url) WHERE source_id = %s".format(
                ",".join(k+"=%s" for k in kwargs.keys()))
            cur.execute(query, tuple(kwargs.values()) + (self.source_id,))
            debug(3, cur._last_executed)
            db.commit()
    
    def save_to_db(self):
        """write object to db"""
        cur = db.cursor()
        fields = [f for f in self.db_fields.keys()
                  if f != 'link_id' and getattr(self, f) is not None]
        values = [getattr(self, f) for f in fields]
        query = "INSERT INTO sources ({}, urlhash) VALUES ({}, MD5(url))".format(
            ",".join(fields), ",".join(("%s",)*len(fields)))
        cur.execute(query, values)
        debug(3, cur._last_executed)
        db.commit()
        self.source_id = cur.lastrowid
    
    def set_html(self, html):
        debug(6, "\n====== %s ======\n%s\n======\n", self.url, html)
        self.html = html
   
    def extract_links(self, browser):
        """
        extracts links from source page; sets self.new_links and
        self.old_links, both lists of Link objects.
        """
        self.new_links = []
        self.old_links = []
        new_links = {} # url => Link
        old_links = {} # url => Link
        
        # lots of try/except because selenium easily crashes:
        try:
            els = browser.find_elements_by_tag_name("a")
        except:
            debug(1, "cannot retrieve links from page %s", self.url)
            return [],[]
        for el in els:
            try:
                if not el.is_displayed():
                    continue
                href = el.get_attribute('href')
                anchortext = el.text
                if not href:
                    continue
            except:
                continue
            if is_bad_url(href):
                debug(3, 'ignoring link to %s (bad url)', href)
                continue
            if href in old_links.keys() or href in new_links.keys():
                debug(3, 'ignoring repeated link to %s', href)
            old_link = self.old_link(href)
            if old_link:
                debug(3, 'link to %s is old', href)
                old_links[href] = old_link
                old_links[href].element = el
            else:
                debug(1, 'new link: "%s" %s', anchortext, href)
                new_links[href] = Link(url=href, source=self, element=el)

        self.new_links = new_links.values()
        self.old_links = old_links.values()
 
    def old_link(self, url):
        """
        If a link to (a session variant of) url is already known on this
        page (as stored in the database), returns the stored Link,
        otherwise returns None.
        """
        if not hasattr(self, '_links'):
            cur = db.dict_cursor()
            query = "SELECT * FROM links WHERE source_id = %s"
            cur.execute(query, (self.source_id,))
            debug(5, cur._last_executed)
            self._links = [ Link(source=self, **li) for li in cur.fetchall() ]
            #debug(2, 'xxx old links:\n%s', '\n'.join([li.url for li in self._links]))

        for li in self._links:
            if li.url == url:
                return li

        s_url = self.strip_session_variables(url)
        if s_url != url:
            for li in self._links:
                if s_url == self.strip_session_variables(li.url):
                    return li

        return None

        # We could also look for session variants in the whole db:
        # pattern = re.sub('(?<='+v+')[\w-]+', '[\\w-]+', url)
        # query = "SELECT url FROM links WHERE url REGEX %s LIMIT 1"
        # cur.execute(query, pattern)
        # variants = cur.fetchall()

class Link():
    """ represents a link on a source page """

    db_fields = {
        'link_id': 0,
        'url': '',
        'source_id': 0,
        'status': 0, # 0 = unprocessed, 1 = OK, >1 = error
        'found_date': None,
        'last_checked': None,
        'etag': None,
        'filesize': None,
        'doc_id': None
    }

    def __init__(self, **kwargs):
        for k,v in self.db_fields.items():
            setattr(self, k, kwargs.get(k, v))
        if not self.found_date:
            self.found_date = datetime.now()
        self.source = kwargs.get('source')
        self.element = kwargs.get('element') # the dom element from Browser
        if self.source:
            self.source_id = self.source.source_id
    
    def html_context(self):
        """
        sets self.anchortext and self.context, where the latter is the
        surrounding text of a link, often containing author, title,
        publication info; returns self.context
        
        There are three main cases:

        (1) The context we're looking for coincides with the content
            of a single DOM element (e.g. the <a> itself, or a <li>),
            possibly minus an abstract, which we can remove
            afterwards.

        (2) The context we're looking for coincides with the content
            of several DOM elements taken together
            (e.g. "<h4>Title</h4> <div>Forthcoming
            <a>Penultimate</a></div>"), possibly minus an abstract.

        (3) The context we're looking for is part of a DOM element
            that also contains contexts for other entries. E.g.,
            "<a>Paper1</a> Forthcoming<br> <a>Paper2</a>", or
            "<h4>Paper1</h4> Forthcoming <a>PDF</a> <h4>Paper2</h4>
            <a>PDF</a>", or "<h4><a>Paper1</a></h4> Forthcoming
            <h4><a>Paper2</a></h4>".

        To tell these apart, we first climb up the DOM tree until we
        reach an element that's too large to be a single paper entry
        (careful of abstracts here). If the element right below (call
        it el) has no further text than the link with which we started
        but there's neighbouring text not in a link, we assume we're
        in case (3); here we crudely divide el's parent by <br> or
        <h*> and return the content of the part surrounding el. To
        tell apart (1) and (2), we use some heuristics to determine
        whether el's context extends to its siblings: e.g., is there a
        gap between el and sibling? does the sibling also contain a
        link to a paper? etc.
        """

        debug(5, 'trying to find link context')
        try:
            self.anchortext = self.element.get_attribute('textContent').strip()
        except Exception as e:
            debug(1, "cannot retrieve link context: %s", str(e))
            self.context = ''
            return self.context

        # First climb up DOM until we reach an element (par) that's
        # too large:
        el = self.element
        par = el.find_element_by_xpath('..')
        debug(5, 'starting with %s', el.get_attribute('outerHTML'))
        el._text = el.get_attribute('textContent')
        while (True):
            debug(5, 'climbing up par: %s', par.get_attribute('outerHTML'))
            # check if parent has many links or other children
            par._links = par.find_elements_by_xpath('.//a')
            par._children = par.find_elements_by_xpath('./*')
            if len(par._links) > 3 or len(par._children) > 5:
                debug(5, 'stopping: too many links or children')
                break
            # List of drafts may only contain two papers, so we also
            # check if the previous element was already fairly
            # large. (We'll still treat such lists as a single context
            # if the entries are very short, but then that's not a
            # serious problem because we won't be misled by
            # publication info that belongs to another entry.)
            par._text = par.get_attribute('textContent')
            if len(el._text) > 70 and len(par._text) > len(el._text)*1.5:
                debug(5, 'stopping: enough text already (%s)', el._text)
                break
            try:
                gpar = par.find_element_by_xpath('..')
                el,par = par,gpar
            except Exception:
                break
        
        # If el has no further text than the link with which we
        # started but there's neighbouring text not in a link, we're
        # in the messy case (3):
        if len(el._text) - len(self.element._text) < 5:
            par._outerHTML = par.get_attribute('outerHTML')
            el._outerHTML = el.get_attribute('outerHTML')
            l,r = par._outerHTML.split(el._outerHTML, 1)
            if re.search(r'\w\s*$', l) or re.search(r'^\s*\w', r):
                debug(5, 'argh: case (3)')
                for pat in (r'<h\d.*?>', r'<br>\s*<br>', r'<br>'):
                    parts = re.split(pat, par._outerHTML, flags=re.I)
                    if len(parts) > 1:
                        break
                for part in parts:
                    if el._outerHTML in part:
                        debug(5, 'surrounding part: %s', part)
                        return util.strip_tags(part)
                # we should never be here
                return el._text
        
        # Now try to figure out if siblings belong to context:
        def context_left(i):
            if par._children.index(el)-i < 0:
                # can't catch IndexError: careful of negative indices!
                return ''
            lsib = par._children[par._children.index(el)-i]
            lsib_outerHTML = lsib.get_attribute('outerHTML')
            debug(5, "add left sibling?: %s", lsib_outerHTML)
            if re.search(r'\.(?:pdf|docx?)\b', lsib_outerHTML, flags=re.I):
                debug(5, "no: contains link to pdf or doc")
                return ''
            lsib_height = int(lsib.get_attribute('offsetHeight'))
            lsib_text = lsib.get_attribute('textContent')
            if lsib_text.strip() == '' and lsib_height > 2:
                debug(5, "no: sibling has no text but takes up space")
                return ''
            lsib_bottom = lsib.location['y'] + lsib_height
            gap = par._children[par._children.index(el)-(i-1)].location['y'] - lsib_bottom
            if gap > 20 or (gap > 10 and len(context) > 20):
                debug(5, "no: too far away (%s)", gap)
                return ''
            debug(5, "yes, expanding context")
            return lsib_text

        def context_right(i):
            try:
                rsib = par._children[par._children.index(el)+i]
            except IndexError:
                return ''
            rsib_outerHTML = rsib.get_attribute('outerHTML')
            debug(5, "add right sibling?: %s", rsib_outerHTML)
            if re.search(r'\.(?:pdf|docx?)\b', rsib_outerHTML, flags=re.I):
                debug(5, "no: contains link to pdf or doc")
                return ''
            if (len(context) > 20 
                and not re.search(r'\d{4}|draft|forthcoming', rsib_outerHTML, flags=re.I)):
                # We're mainly interested in author, title,
                # publication info. The first two never occur after
                # the link element (unless that is very short: e.g. an
                # icon), so we only need to check for the third.
                debug(5, "no: doesn't look like publication info")
                return ''
            rsib_height = int(rsib.get_attribute('offsetHeight'))
            rsib_text = rsib.get_attribute('textContent')
            if rsib_text.strip() == '' and rsib_height > 2:
                debug(5, "no: sibling has no text but takes up space")
                return ''
            rsiblsib = par._children[par._children.index(el)+(i-1)]
            rsiblsib_bottom = rsiblsib.location['y'] + int(rsiblsib.get_attribute('offsetHeight'))
            gap = rsib.location['y'] - rsiblsib_bottom
            if gap > 20 or (gap > 10 and len(context) > 20):
                debug(5, "no: too far away (%s)", gap)
                return ''
            debug(5, "yes, expanding context")
            return rsib_text

        context = el.get_attribute('textContent')
        debug(5, "initial context: %s", context)
        for i in (1,2,3):
            more = context_right(i)
            if not more: break
            context += '\n' + more
        for i in (1,2,3,4):
            more = context_left(i)
            if not more: break
            context = more + '\n' + context
        # tidy up slightly (mainly for easier testing):
        self.context = re.sub(r'\s*\n+\s*', r'\n', context).strip()
        return self.context

    def load_from_db(self, url='', source_id=0):
        url = url or self.url
        source_id = source_id or self.source_id
        if not url or not source_id:
            raise TypeError("need url and source_id to load Link from db")
        
        cur = db.dict_cursor()
        query = "SELECT * FROM links WHERE urlhash = MD5(%s) AND source_id = %s LIMIT 1"
        cur.execute(query, (url, source_id))
        debug(5, cur._last_executed)
        links = cur.fetchall()
        if links:
            for k,v in links[0].items():
                setattr(self, k, v)
        else:
            debug(4, "link to %s not in database", url)
    
    def update_db(self, **kwargs):
        """
        update self.**kwargs and write present state to db, also set
        'last_checked'
        """
        for k,v in kwargs.items():
            setattr(self, k, v)
        cur = db.cursor()
        self.last_checked = datetime.now()
        fields = [f for f in self.db_fields.keys()
                  if f != 'link_id' and getattr(self, f) is not None]
        values = [getattr(self, f) for f in fields]
        if self.link_id:
            query = "UPDATE links SET {},urlhash=MD5(url) WHERE link_id = %s".format(
                ",".join(k+"=%s" for k in fields))
            cur.execute(query, values + [self.link_id])
        else:
            query = "INSERT INTO links ({},urlhash) VALUES ({},MD5(url))".format(
                ",".join(fields), ",".join(("%s",)*len(fields)))
            try:
                cur.execute(query, values)
            except:
                debug(1, "oops, %s: %s", query, ','.join(map(str, values)))
                raise
            self.link_id = cur.lastrowid
        debug(4, cur._last_executed)
        db.commit()

    def fetch(self, url=None, only_if_modified=True):
        '''
        fetch linked document (or url), returns response object on
        success, otherwise stores error in db and returns None.
        '''
        time.sleep(1) # be gentle on servers
        url = url or self.url
        if only_if_modified and self.last_checked:
            ims = self.last_checked.strftime('%a, %d %b %Y %H:%M:%S GMT')
            status,r = util.request_url(url, if_modified_since=ims, etag=self.etag)
            if (status == 304 or
                status == 200 and r.headers.get('content-length') == self.filesize):
                self.update_db()
                debug(1, "not modified")
                return None
        else:
            status,r = util.request_url(url)
        if status != 200:
            self.update_db(status=status)
            debug(1, "error status %s", status)
            return None
        if not r.text:
            self.update_db(status=error.code['document is empty'])
            debug(1, 'document is empty')
            return None
        self.etag = r.headers.get('etag')
        self.filesize = r.headers.get('content-length')
        return r

class Doc():
    """ represents a paper """

    db_fields = {
        'doc_id': 0,
        'url': '',
        'doctype': 'article',
        'status': 1,
        'filetype': None,
        'filesize': 0,
        'found_date': None,
        'earlier_id': None,
        'authors': '',
        'title': '',
        'abstract': '',
        'numwords': 0,
        'numpages': 0,
        'source_url': '',
        'source_name': '',
        'source_id': 0,
        'meta_confidence': 0, # 0-100
        'is_paper': 0, # 0-100
        'is_philosophy': 0, # 0-100
        'hidden': False,
        'content': ''
    }

    def __init__(self, **kwargs):
        for k,v in self.db_fields.items():
            setattr(self, k, kwargs.get(k, v))
        if not self.found_date:
            self.found_date = datetime.now()
        self.r = kwargs.get('r', None)
        if self.r:
            self.filetype = kwargs.get('filetype', self.r.filetype)
        self.link = kwargs.get('link', None)
        if self.link:
            self.filesize = kwargs.get('filesize', self.link.filesize)
        self.source = kwargs.get('source', self.link.source if self.link else None)
        if self.source:
            self.source_url = kwargs.get('source_url', self.source.url)
            self.source_name = kwargs.get('source_name', self.source.name)
            self.source_id = kwargs.get('source_id', self.source.source_id)
        self.ocr = False
    
    def load_from_db(self, doc_id=None, url=None):
        doc_id = doc_id or self.doc_id
        url = url or self.url
        cur = db.dict_cursor()
        if doc_id:
            query = "SELECT * FROM docs WHERE doc_id = %s"
            cur.execute(query, (doc_id,))
        elif url:
            query = "SELECT * FROM docs WHERE urlhash = MD5(%s)"
            cur.execute(query, (url,))
        else:
            raise TypeError("need doc_id or url to load doc from db")
        debug(5, cur._last_executed)
        docs = cur.fetchall()
        if docs:
            for k,v in docs[0].items():
                setattr(self, k, v)
            return True
        else:
            debug(4, "no doc with id %s or url %s in database", doc_id, url)
            return False

    def update_db(self, **kwargs):
        """update self.**kwargs and write present state to db"""
        for k, v in kwargs.items():
            setattr(self, k, v)
        cur = db.cursor()
        fields = [f for f in self.db_fields.keys()
                  if f != 'doc_id' and getattr(self, f) is not None]
        values = [getattr(self, f) for f in fields]
        if self.doc_id:
            query = "UPDATE docs SET {},urlhash=MD5(url) WHERE doc_id = %s".format(
                ",".join(k+"=%s" for k in fields))
            cur.execute(query, values + [self.doc_id])
        else:
            query = "INSERT INTO docs ({},urlhash) VALUES ({},MD5(url))".format(
                ",".join(fields), ",".join(("%s",)*len(fields)))
            cur.execute(query, values)
            self.doc_id = cur.lastrowid
        debug(4, cur._last_executed)
        db.commit()
        
    def assign_category(self, cat_id, strength):
        """inserts or updates a docs2cats entry in the db"""
        if not self.doc_id:
            raise Exception("cannot assign category: document has no id")
        cur = db.cursor()
        query = ("INSERT INTO docs2cats (cat_id, doc_id, strength) VALUES (%s,%s,%s)"
                 " ON DUPLICATE KEY UPDATE strength=%s")
        cur.execute(query, (cat_id, self.doc_id, strength, strength))
        debug(4, cur._last_executed)
        db.commit()

    @property
    def default_author(self):
        """
        returns doc.source.default_author if that is defined (i.e., if
        doc.source is a personal page), otherwise tries to extract an
        author candidate from doc.link.context.

        The metadata extractor (docparser.paperparser) uses this
        property as default author if no author string can be found in
        the document, and to evaluate the plausibility of candidate
        author strings.

        Unfortunately, journal pages tend to put the author name in
        unpredictable places, often outside what is recognized as the
        link context. On the other hand, journal publications reliably
        contain the author name(s) in the document. So here we don't
        bother setting default_author at the moment. On repository
        pages, people do sometimes upload papers that don't contain
        any author names. 

        The metadata extractor assumes that default_author is a
        single author, because personal homepages only have a single
        default author. People also usually don't forget to put their
        names in the paper if there are co-authors. So we return the
        first author only.

        On philsci-archive, the format is 

        Teller, Paul (2016) Role-Player Realism.
        Livengood, Jonathan and Sytsma, Justin and Rose, David (2016) Following...

        On philpapers, it is 

        Stefan Dragulinescu, Mechanisms and Difference-Making.
        Michael Baumgartner & Lorenzo Casini, An Abductive Theory of Constitution.

        How do we know "Stefan Dragulinescu, Mechanisms" isn't the
        name of a person called "Mechanisms Stefan Dragulinescu" in
        last-comma-first format? Ultimately, we should use some clever
        general heuristics here. For now we simply split at /,| &|
        and|\(/; if the first element contains a whitespace, we return
        that element, otherwise we concatenate the first two elements
        in reverse order. This will only retrieve the surname on
        philsci-archive for authors with a double surname. 

        TODO: improve.
        """
        try:
            if self.source.sourcetype != 'repo':
                return self.source.default_author
            re_split = re.compile(',| & | and|\(')
            au, rest = re_split.split(self.link.context.strip(), 1)
            if len(au.split()) == 1:
                au2, rest2 = re_split.split(rest, 1)
                au = au2 + ' ' + au
            debug(3, 'setting "%s" as default_author', au)
            return au
        except Exception as e:
            return ''

def is_bad_url(url):
    if len(url) > 512:
        debug(1, 'url %s is too long', url)
        return True
    re_bad_url = re.compile("""
                ^\#|
                ^mailto|
                ^data|
                ^javascript|
                ^.+//[^/]+/?$|          # TLD
                twitter\.com|
                fonts\.googleapis\.com|
                philpapers\.org/asearch|
                \.(?:css|mp3|avi|mov|jpg|gif|ppt|png|ico|mso|xml)(?:\?.+)?$   # .css?version=12
                """, re.I | re.X)
    return re_bad_url.search(url) is not None

def categories():
    """returns list of (cat_id,cat_label) pairs from db"""
    try:
        return categories.cats
    except AttributeError:
        cur = db.cursor()
        query = ("SELECT cat_id, label FROM cats WHERE label != 'philosophy' AND label != 'blogspam'")
        cur.execute(query)
        categories.cats = list(cur.fetchall())
        return categories.cats
