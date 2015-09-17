import logging
import re
import sys
import MySQLdb
import requests
import json
import urllib
import smtplib
from email.mime.text import MIMEText
from subjectivebayes import BinaryNaiveBayes
from config import config

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class SourcesFinder:

    def __init__(self):
        self.pagefinder = PapersPageFinder()

    def select_names(self, num):
        db = self.get_db()
        cur = db.cursor()
        query = "SELECT name FROM author_names ORDER BY last_searched ASC LIMIT {}".format(num)
        cur.execute(query)
        rows = cur.fetchall()
        return [row[0] for row in rows]

    def run(self):
        num_names = 1
        new_pages = []
        for name in self.select_names(num_names):
            logger.info(u"searching papers page(s) for {}".format(name))
            pages = self.pagefinder.search(name)
            db = self.get_db()
            cur = db.cursor()
            for url in pages:
                logger.info(u"papers page for {}: {}".format(name, url))
                try:
                    query = "INSERT INTO sources (status,type,url,default_author,name) VALUES (0,1,%s,%s,%s)"
                    cur.execute(query, (url,name,u"{}'s site".format(name)))
                    db.commit()
                    new_pages.append((name,url))
                except MySQLdb.IntegrityError:
                    logger.debug(u"{} already in db".format(url))
            else:
                logger.info("no pages found")
            query = "UPDATE author_names SET last_searched=NOW() WHERE name=%s"
            cur.execute(query, (name,))
            db.commit()
        if new_pages:
            self.sendmail(new_pages)
        
    def sendmail(self, new_pages):
        body = u''
        for (name, url) in new_pages:
            body += u"new source page {} for {}\n".format(url,name)
            body += "Edit: http://umsu.de/opp/edit-source?url={}\n\n".format(url)
        msg = MIMEText(body, 'plain', 'utf-8')
        msg['Subject'] = '[new source pages]'
        msg['From'] = 'Philosophical Progress <opp@umsu.de>'
        msg['To'] = 'wo@umsu.de'
        s = smtplib.SMTP('localhost')
        s.sendmail(msg['From'], [msg['To']], msg.as_string())
        s.quit()

    def get_db(self):
        if not hasattr(self, 'db'):
            self.db = MySQLdb.connect('localhost',
                                      config('MYSQL_USER'), config('MYSQL_PASS'), config('MYSQL_DB'),
                                      charset='utf8', use_unicode=True)
        return self.db


class PapersPageFinder:

    def __init__(self):
        self.classifier = BinaryNaiveBayes(prior_yes=0.6)
        self.classifier.likelihood(
            "journal url",
            lambda r: re.search(r'jstor.org|springer.com|wiley.com|journals.org', r.url),
            p_yes=0, p_no=0.1)
        self.classifier.likelihood(
            "contains at least 2 links to '.pdf' or '.doc'",
            lambda r: len(re.findall(r'href=[^>]+\.(?:pdf|docx?)\b', r.text, re.IGNORECASE)) > 1,
            p_yes=0.99, p_no=0.2)
        self.classifier.likelihood(
            "contains 'syllabus'",
            lambda r: 'syllabus' in r.textlower,
            p_yes=0.1, p_no=0.2)
        self.classifier.likelihood(
            "contains conference keywords",
            lambda r: r.textlower.count('schedule') + r.textlower.count('break') + r.textlower.count('dinner') > 2,
            p_yes=0.01, p_no=0.2)
        self.classifier.likelihood(
            "author name in url",
            lambda r: r.authorname.split()[-1].lower() in r.url.lower(),
            p_yes=0.6, p_no=0.1)

    def search(self, name):
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
        search_phrase = '"{}" '.format(name) + ' '.join(search_terms),
        searchresults = set(self.websearch(search_phrase))
        search_phrase = '"{}" '.format(name.split()[-1]) + ' '.join(search_terms)
        searchresults |= set(self.websearch(search_phrase))
        for url in searchresults:
            logger.debug("\n")
            url = urllib.unquote(url) 
            try:
                r = self.fetch(url)
            except:
                logger.debug("cannot retrieve {}".format(url))
            else:
                score = self.evaluate(r, name)
                if score > 0.7:
                    pages.add(url)
        return pages

    def websearch(self, phrase):
        url = 'http://ajax.googleapis.com/ajax/services/search/web?' 
        params = { 'q': phrase, 'v': '1.0' }
        # make sure params are encoded into str:
        for k,v in params.iteritems():
            params[k] = unicode(v).encode('utf-8')
        url += urllib.urlencode(params)
        r = self.fetch(url)
        #logger.debug(r.content)
        data = json.loads(r.text)
        urls = [res['url'] for res in data['responseData']['results']]
        return urls
        
    def evaluate(self, response, name):
        response.textlower = response.text.lower()
        response.authorname = name
        p_source = self.classifier.test(response)
        return p_source

    def fetch(self, url):
        headers = { 'User-agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:37.0) Gecko/20100101 Firefox/37.0' }
        logger.debug("fetching {}".format(url))
        return requests.get(url, headers=headers)
        
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
        for name, sites in tests.iteritems():
            print "\n\ntesting {}".format(name)
            urls = sf.search(name)
            if urls == sites:
                print "   OK"
            else:
                print "   expected: {}, got: {}".format(sites, urls)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        pf = PapersPageFinder()
        print pf.search(sys.argv[1])
        sys.exit(0)
    else:
        sf = SourcesFinder()
        sf.run()
        sys.exit(0)

