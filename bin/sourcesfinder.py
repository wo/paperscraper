import argparse
import logging
import re
import sys
import findmodules
import hashlib
from opp import db, util, googlesearch
from opp.models import Source
from opp.debug import debug, debuglevel
import json
import urllib

'''
This script is supposed to be run from the command line (or regularly
as a cron job) to find new source pages.
'''

class SourcesFinder:

    def __init__(self):
        pass
    
    def select_names(self, num_names):
        """return list of num names names from db to check for new papers pages"""
        cur = db.cursor()
        query = "SELECT name FROM author_names WHERE is_name=1 ORDER BY last_searched ASC LIMIT {}".format(num_names)
        cur.execute(query)
        rows = cur.fetchall()
        return [row[0] for row in rows]

    def update_author(self, name):
        """update last_searched field for author <name>"""
        cur = db.cursor()
        query = "UPDATE author_names SET last_searched=NOW() WHERE name=%s"
        cur.execute(query, (name,))
        db.commit()

    def find_new_pages(self, name, store_in_db=True):
        """
        searches for Source pages matching author name and adds them to
        the sources db
        """
        debug(1, "\nsearching source pages for %s", name)
        stored_publications = Source.get_stored_publications(name)
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
            debug(1, '\n'+url)
            url = util.normalize_url(url)
            if self.bad_url(url):
                debug(1, "bad url")
                continue
            # check if url is already known:
            cur = db.cursor()
            cur.execute("SELECT 1 FROM sources WHERE url = %s", (url,))
            rows = cur.fetchall()
            if rows:
                debug(1, "url already known")
                continue
            try:
                status, r = util.request_url(url)
                if status != 200:
                    raise Exception('status {}'.format(status))
            except Exception as e:
                debug(1, "cannot retrieve url %s (%s)", url, e)
                continue
            source = Source(
                url=url,
                default_author=name,
                name="{}'s site".format(name),
                html=r.text
            )
            score = source.probability_sourcepage(stored_publications=stored_publications)
            if score < 0.5:
                debug(1, "doesn't look like a papers page")
                continue
            for dupe in source.get_duplicates():
                # Now what? Sometimes the present URL is the
                # correct new URL to use (e.g., everything is
                # moving to 'https'). Other times the variants are
                # equally valid. In neither case does it probably
                # hurt to overwrite the old URL.
                debug(1, "duplicate of already known %s", dupe.url)
                debug(1, "changing url of source %s to %s", dupe.source_id, url)
                dupe.update_db(url=url)
                break
            else:
                debug(1, "new papers page!")                
                source.save_to_db()
        self.update_author(name)

    def bad_url(self, url):
        """returns True if url contains blacklisted part"""
        url = url.lower()
        return any(w in url for w in self.BAD_URL_PARTS)

    BAD_URL_PARTS = [
        'jstor.org', 'springer.com', 'wiley.com', 'journals.org',
        'tandfonline.com', 'ssrn.com', 'oup.com', 'mitpress.mit.edu',
        'dblp.uni-trier', 'citec.repec.org', 'publicationslist.org',
        '/portal/en/', # PURE
        'wikivisually.com',
        'researchgate.net', 'scholar.google', 'books.google', 'philpapers.',
        'amazon.', 'twitter.', 'goodreads.com',
        'dailynous.com', 'ipfs.io/', 'philostv.com', 'opp.weatherson',
        'typepad.com/blog/20', 'm-phi.blogspot.de',
        'blogspot.com/20', 'whatisitliketobeaphilosopher.com',
        'workshop', 'courses', '/teaching', 'conference',
        '/call', '/search', '/lookup',
    ]

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
            urls = sf.find_new_pages(name, store_in_db=False)
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
    logger = logging.getLogger('opp')
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(loglevel)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logger.addHandler(ch)
    logger.setLevel(loglevel)
    debuglevel(4 if args.verbose else 1)

    sf = SourcesFinder()
    if args.name:
        names = [args.name]
    else:
        names = sf.select_names(num_names=1)
    for name in names:
        pages = sf.find_new_pages(name, store_in_db=(not args.dry))
     
    sys.exit(0)
