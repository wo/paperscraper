#!/usr/bin/python3.4
import argparse
import logging
import re
import sys
import findmodules
from opp import db, util, googlesearch
from opp.subjectivebayes import BinaryNaiveBayes 
import json
import urllib

class SourcesFinder:

    def __init__(self):
        self.page_classifier = self.make_page_classifier()
    
    def select_names(self, num_names):
        """return list of num names names from db to check for new papers pages"""
        cur = db.cursor()
        query = "SELECT name FROM author_names WHERE is_name=1 ORDER BY last_searched ASC LIMIT {}".format(num_names)
        cur.execute(query)
        rows = cur.fetchall()
        return [row[0] for row in rows]

    def store_page(self, url, name):
        """write page <url> for author <name> to db"""
        cur = db.cursor()
        query = "INSERT INTO sources (status,sourcetype,url,default_author,name,found_date)"
        query += "VALUES (0,'personal',%s,%s,%s, NOW())"
        cur.execute(query, (url,name,"{}'s site".format(name)))
        db.commit()
    
    def update_author(self, name):
        """update last_searched field for author <name>"""
        cur = db.cursor()
        query = "UPDATE author_names SET last_searched=NOW() WHERE name=%s"
        cur.execute(query, (name,))
        db.commit()

    def find_new_pages(self, name):
        """searches for papers pages matching author name, returns urls of new pages"""
        logger.info("\nsearching papers page(s) for %s", name)
        pages = set()
        search_terms = [
            # careful with google.com: don't block sites.google.com...
            '-site:academia.edu',
            '-site:wikipedia.org',
            '-site:philpapers.org',
            '-filetype:pdf',
            '~philosophy',
            '(publications OR articles OR papers OR "in progress" OR forthcoming)',
        ]
        # search full name first, then last name only:
        search_phrase = '"{}" '.format(name) + ' '.join(search_terms)
        searchresults = set(googlesearch.search(search_phrase))
        search_phrase = '"{}" '.format(name.split()[-1]) + ' '.join(search_terms)
        searchresults |= set(googlesearch.search(search_phrase))
        for url in searchresults:
            logger.debug("\n")
            url = util.normalize_url(url) 
            if self.bad_url(url):
                logger.info("bad url: %s", url)
                continue
            # check if url already known:
            cur = db.cursor()
            cur.execute("SELECT 1 FROM sources WHERE url = %s", (url,))
            rows = cur.fetchall()
            if rows:
                logger.info("%s already known", url)
                continue
            try:
                status, r = util.request_url(url)
                if status != 200:
                    raise Exception('status {}'.format(status))
            except:
                logger.info("cannot retrieve %s", url)
            else:
                score = self.evaluate(r, name)
                if score < 0.7:
                    logger.info("%s doesn't look like a papers page", url)
                    continue
                dupe = self.is_duplicate(url)
                if dupe:
                    logger.info("%s is a duplicate of already known %s", url, dupe)
                    continue
                logger.info("new papers page for %s: %s", name, url)                
                pages.add(url)
        if not pages:
            logger.info("no pages found")
        self.update_author(name)
        return pages

    def bad_url(self, url)
        """returns True if url contains blacklisted part"""
        for bad in self.BAD_URL_PARTS:
            if bad in response.url:
                return True
        return False

    BAD_URL_PARTS = [
        'jstor.org', 'springer.com', 'wiley.com', 'journals.org',
        'scholar.google', 'books.google',
        'amazon.com',
        'suche', 'search', 'lookup',
        '/cv', '/curriculum-vitae',
        '/call',
    ]

    def evaluate(self, response, name):
        """return probability that <response> is a papers page for <name>"""
        response.textlower = response.text.lower()
        response.authorname = name
        p_source = self.page_classifier.test(response)
        return p_source

    def make_page_classifier(self):
        """set up classifier to evaluate whether a page (Response object) is a papers source"""
        classifier = BinaryNaiveBayes(prior_yes=0.6)
        classifier.likelihood(
            "contains at least 2 links to '.pdf' or '.doc'",
            lambda r: len(re.findall(r'href=[^>]+\.(?:pdf|docx?)\b', r.text, re.IGNORECASE)) > 1,
            p_ifyes=0.99, p_ifno=0.2)
        classifier.likelihood(
            "contains 'syllabus'",
            lambda r: 'syllabus' in r.textlower,
            p_ifyes=0.1, p_ifno=0.2)
        classifier.likelihood(
            "contains conference keywords",
            lambda r: r.textlower.count('schedule') + r.textlower.count('break') + r.textlower.count('dinner') > 2,
            p_ifyes=0.01, p_ifno=0.2)
        classifier.likelihood(
            "author name in url",
            lambda r: r.authorname.split()[-1].lower() in r.url.lower(),
            p_ifyes=0.6, p_ifno=0.1)
        return classifier

    def is_duplicate(self, url):
        """
        check if page is already in db under superficially different URL:
        with(out) trailing slash or with(out) 'www'.

        One should also check if the same page is available e.g. as
        /user/1076 and as /user/sjones. But that's tricky. Perhaps
        this functionality should be added to process_pages, where I
        could check if a new page contains any links to papers that
        haven't also been found elsewhere and if not mark it as
        inactive. TODO
        """
        cur = db.cursor()
        m = re.match('^(https?://)(www\.)?(.+?)(/)?$', url)
        if not m:
            logger.warn('malformed url %s?', url)
            return None
        urlvars = [
            m.group(1)+m.group(3), # no 'www.', no trailing slash
            m.group(1)+m.group(3)+'/', # no 'www.', trailing slash
            m.group(1)+'www.'+m.group(3), # 'www.', no trailing slash 
            m.group(1)+'www.'+m.group(3)+'/' # 'www.', trailing slash 
        ]
        cur.execute("SELECT url FROM sources WHERE url IN (%s, %s, %s, %s)", urlvars)
        rows = cur.fetchall()
        if rows:
            return rows[0][0]
        return None

    def sendmail(self, new_pages):
        body = ''
        for (name, url) in new_pages:
            body += "new source page {} for {}\n".format(url,name)
            body += "Edit: http://umsu.de/opp/edit-source?url={}\n\n".format(url)
        #msg = MIMEText(body, 'plain', 'utf-8')
        #msg['Subject'] = '[new source pages]'
        #msg['From'] = 'Philosophical Progress <opp@umsu.de>'
        #msg['To'] = 'wo@umsu.de'
        #s = smtplib.SMTP('localhost')
        #s.sendmail(msg['From'], [msg['To']], msg.as_string())
        #s.quit()

    def test(self):
        tests = {
            # easy cases:
            'Wolfgang Schwarz': { 'http://www.umsu.de/papers/' },
            'Bryan Pickel': { 'https://sites.google.com/site/bryanpickel/Home/re' },
            'Brian Rabern': { 'https://sites.google.com/site/brianrabern/' },
            # no separate papers page:
            'Ted Sider': { 'http://tedsider.org' },
            'Michael Smith': { 'http://www.princeton.edu/~msmith/' },
            'Aaron James': { 'http://www.faculty.uci.edu/profile.cfm?faculty_id=4884' },
            # paper links on many pages:
            'Brian Weatherson': { 'http://brian.weatherson.org/papers.html' },
            # author name not on papers page:
            'Aaron J Cotnoir': { 'http://www.st-andrews.ac.uk/~ac117/writing.html' },
            'Adam Morton': { 'http://www.fernieroad.ca/a/PAPERS/papers.html' }, 
        }
        sf = SourcesFinder()
        for name, sites in tests.items():
            print("\n\ntesting {}".format(name))
            urls = sf.find_new_pages(name)
            if urls == sites:
                print("   OK")
            else:
                print("   expected: {}, got: {}".format(sites, urls))


if __name__ == "__main__":

    ap = argparse.ArgumentParser()
    ap.add_argument('-v', '--verbose', action='store_true', help='turn on debugging output')
    ap.add_argument('-n', '--name', type=str, help='search source pages for given author name')
    ap.add_argument('-d', '--dry', action='store_true', help='do not store pages in db')
    args = ap.parse_args()

    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.basicConfig(level=(logging.DEBUG if args.verbose else logging.INFO))
    logger = logging.getLogger(__name__)

    sf = SourcesFinder()
    if args.name:
        names = [args.name]
    else:
        names = sf.select_names(num_names=1)
    print(names)
    for name in names:
        pages = sf.find_new_pages(name)
        if not args.dry:
            for url in pages:
                sf.store_page(url, name)
    sys.exit(0)
