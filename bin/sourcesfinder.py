import argparse
import logging
import re
import sys
import findmodules
import hashlib
from scipy.stats import nbinom
from opp import db, util, googlesearch, philpaperssearch
from opp.subjectivebayes import BinaryNaiveBayes 
import json
import urllib

'''
This script is supposed to be run from the command line (or regularly
as a cron job) to find new source pages.
'''

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
        urlhash = hashlib.md5(url.encode('utf-8')).hexdigest()
        sourcename = "{}'s site".format(name)
        cur = db.cursor()
        query = "INSERT INTO sources (status,confirmed,sourcetype,url,urlhash,default_author,name,found_date)"
        query += "VALUES (0,0,'personal',%s,%s,%s,%s,NOW())"
        cur.execute(query, (url,urlhash,name,sourcename))
        db.commit()
    
    def update_author(self, name):
        """update last_searched field for author <name>"""
        cur = db.cursor()
        query = "UPDATE author_names SET last_searched=NOW() WHERE name=%s"
        cur.execute(query, (name,))
        db.commit()

    def find_new_pages(self, name):
        """searches for papers pages matching author name, returns urls of new pages"""
        logger.info("\nsearching source pages for %s", name)
        stored_publications = self.get_stored_publications(name)
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
        logger.debug(search_phrase)
        searchresults = googlesearch.search(search_phrase)
        #searchresults = set(googlesearch.search(search_phrase))
        #search_phrase = '"{}" '.format(name.split()[-1]) + ' '.join(search_terms)
        #searchresults |= set(googlesearch.search(search_phrase))
        for url in searchresults:
            logger.info('\n'+url)
            url = util.normalize_url(url)
            if self.bad_url(url):
                logger.info("bad url")
                continue
            # check if url already known:
            cur = db.cursor()
            cur.execute("SELECT 1 FROM sources WHERE url = %s", (url,))
            rows = cur.fetchall()
            if rows:
                logger.info("url already known")
                continue
            try:
                status, r = util.request_url(url)
                if status != 200:
                    raise Exception('status {}'.format(status))
            except Exception as e:
                logger.info("cannot retrieve url %s (%s)", url, e)
            else:
                score = self.evaluate(r, name, stored_publications)
                if score < 0.7:
                    logger.info("doesn't look like a papers page")
                    continue
                dupe = self.is_duplicate(url)
                if dupe:
                    logger.info("duplicate of already known %s", dupe)
                    continue
                logger.info("new papers page!")                
                pages.add(url)
        if not pages:
            logger.info("no pages found")
        self.update_author(name)
        return pages

    def bad_url(self, url):
        """returns True if url contains blacklisted part"""
        url = url.lower()
        return any(w in url for w in self.BAD_URL_PARTS)

    BAD_URL_PARTS = [
        'jstor.org', 'springer.com', 'wiley.com', 'journals.org',
        'tandfonline.com', 'ssrn.com', 'oup.com', 'mitpress.mit.edu',
        'dblp.uni-trier', 'citec.repec.org', 'publicationslist.org',
        '/portal/en/', # PURE
        'researchgate.net', 'scholar.google', 'books.google', 'philpapers.',
        'amazon.', 'twitter.', 'goodreads.com',
        'dailynous.com', 'ipfs.io/', 'philostv.com', 'opp.weatherson',
        'typepad.com/blog/20', 'm-phi.blogspot.de',
        'blogspot.com/20', 'whatisitliketobeaphilosopher.com',
        'workshop', 'courses',
        'wikivisually.com',
        '/cv', '/curriculum-vitae', '/teaching', 'conference',
        '/call', '/search', '/lookup',
    ]

    def get_stored_publications(self, name):
        """
        return list of publication titles for <name> from DB; if none are
        stored, try to fetch some from philpapers

        We do this for two reasons: First, because the list of known
        publications helps decide whether something is a source
        page. Second, we need a list of known publications later, when
        processing papers, to decide whether a paper is new or
        not. Here is a good point at which to create this list.
        """
        cur = db.cursor()
        query = "SELECT title FROM publications WHERE author=%s"
        cur.execute(query, (name,))
        rows = cur.fetchall()
        if rows:
            logger.info("%s publications stored for %s", len(rows), name)
            return [row[0] for row in rows]
        
        logger.info("no publications stored for %s; searching philpapers", name)
        pubs = philpaperssearch.get_publications(name)
        logger.info('{} publications found on philpapers'.format(len(pubs)))
        for pub in pubs:
            query = "INSERT INTO publications (author, title, year) VALUES (%s,%s,%s)"
            cur.execute(query, (name, pub[0], pub[1]))
            logger.debug(cur._last_executed)
        db.commit()
        return [pub[0] for pub in pubs]

    def evaluate(self, response, name, stored_publications):
        """return probability that <response> is a papers page for <name>"""
        response.textlower = response.text.lower()
        doclinks = re.findall(r'href=([^>]+\.(?:pdf|docx?)\b)', response.textlower)
        response.doclinks = [s for s in doclinks if not 'cv' in s]
        response.authorname = name
        response.stored_publications = stored_publications
        p_source = self.page_classifier.test(response, debug=args.verbose, smooth=True)
        return p_source
    
    def make_page_classifier(self):
        """set up classifier to evaluate whether a page (Response object) is a papers source"""
        classifier = BinaryNaiveBayes(prior_yes=0.6)
        classifier.likelihood(
            "any links to '.pdf' or '.doc' files",
            lambda r: len(r.doclinks) > 0,
            p_ifyes=1, p_ifno=.6)
        classifier.likelihood(
            "links to '.pdf' or '.doc' files",
            lambda r: len(r.doclinks),
            p_ifyes=nbinom(2.5,.1), p_ifno=nbinom(.1,.1))
        classifier.likelihood(
            "contains titles of stored publications",
            lambda r: any(title.lower() in r.textlower for title in r.stored_publications),
            p_ifyes=0.8, p_ifno=0.2)
        classifier.likelihood(
            "contains publication status keywords",
            lambda r: any(word in r.textlower for word in ('forthcoming', 'draft', 'in progress', 'preprint')),
            p_ifyes=0.8, p_ifno=0.2)
        classifier.likelihood(
            "contains 'syllabus'",
            lambda r: 'syllabus' in r.textlower,
            p_ifyes=0.1, p_ifno=0.2)
        classifier.likelihood(
            "contains conference keywords",
            lambda r: r.textlower.count('schedule') + r.textlower.count('break') + r.textlower.count('dinner') > 2,
            p_ifyes=0.01, p_ifno=0.2)
        classifier.likelihood(
            "contains commercial keywords",
            lambda r: any(word in r.textlower for word in ('contact us', 'sign up', 'sign in', 'log in', 'terms and conditions')),
            p_ifyes=0.05, p_ifno=0.5)
        classifier.likelihood(
            "author name in url",
            lambda r: r.authorname.split()[-1].lower() in r.url.lower(),
            p_ifyes=0.6, p_ifno=0.1)
        return classifier

    def is_duplicate(self, url):
        """
        check if page is already in db under superficially different URL:
        with(out) trailing slash or with(out) SSL or with(out) 'www'.

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
        urlpath = m.group(3)
        urlvars = []
        for protocol in ('http://', 'https://'):
            for www in ('www.', ''):
                for slash in ('/', ''):
                    urlvars.append(protocol+www+urlpath+slash)
        cur.execute("SELECT url FROM sources WHERE url IN (%s,%s,%s,%s,%s,%s,%s,%s)", urlvars)
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

    loglevel = logging.DEBUG if args.verbose else logging.INFO
    logger = logging.getLogger(__name__)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(loglevel)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logger.addHandler(ch)
    logger.setLevel(loglevel)

    sf = SourcesFinder()
    if args.name:
        names = [args.name]
    else:
        names = sf.select_names(num_names=1)
    for name in names:
        pages = sf.find_new_pages(name)
        if not args.dry:
            for url in pages:
                sf.store_page(url, name)
                
    sys.exit(0)
