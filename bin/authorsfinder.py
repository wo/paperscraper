#!/usr/bin/env python3
import argparse
import sys
import re
import logging
import findmodules
import datetime
import math
import pymysql
from opp import db, util
from opp.sendmail import sendmail

#logger = logging.getLogger(__name__)
#ch = logging.StreamHandler(sys.stdout)
#ch.setLevel(logging.INFO)
#logger.addHandler(ch)
#logger.setLevel(logging.INFO)

class AuthorsFinder:

    journals = [
        'https://philpapers.org/pub/2563', # AJL
        'https://philpapers.org/pub/103', # AJP
        'https://philpapers.org/pub/158', # BJPS
        'https://philpapers.org/pub/53', # Analysis
        #'https://philpapers.org/pub/120', # Behavioral and Brain Sciences
        'https://philpapers.org/pub/178', # Canadian Journal of Philosophy
        'https://philpapers.org/pub/283', # Dialectica
        'https://philpapers.org/pub/319', # Erkenntnis
        'https://philpapers.org/pub/324', # Ethical Theory and Moral Practice
        'https://philpapers.org/pub/325', # Ethics
        'https://philpapers.org/pub/10486', # Ergo
        'https://philpapers.org/pub/420', # Inquiry
        'https://philpapers.org/pub/568', # JPL
        'https://philpapers.org/pub/570', # JoP
        'https://philpapers.org/pub/647', # Linguistics and Philosophy
        'https://philpapers.org/pub/682', # Mind
        'https://philpapers.org/pub/733', # Nous
        'https://philpapers.org/pub/771', # Phil Imprint
        'https://philpapers.org/pub/774', # Philosophia Mathematica
        'https://philpapers.org/pub/795', # Phil Quarterly
        'https://philpapers.org/pub/798', # Phil Review
        'https://philpapers.org/pub/799', # Phil Studies
        'https://philpapers.org/pub/816', # PPR
        'https://philpapers.org/pub/819', # Philosophy and Public Affairs
        'https://philpapers.org/pub/822', # Phil Compass
        'https://philpapers.org/pub/827', # PoS
        'https://philpapers.org/pub/880', # Proceedings of the Arist Soc
        #'https://philpapers.org/pub/1053', # Studies in Hist and PoS
        'https://philpapers.org/pub/1066', # Synthese
        #'https://philpapers.org/pub/1091', # Theory and Decision
    ]

    def __init__(self):
        pass

    def select_journals(self):
        # if run as a daily cron job, cycles through the whole list once every week
        day = datetime.datetime.today().weekday()
        num = int(math.ceil(len(self.journals) / 7))
        return self.journals[day*num : day*num+num]

    def get_authornames(self, journal_url):
        status,r = util.request_url(journal_url)
        ms = re.findall(r"<span class='name'>(.+?)</span>", r.text)
        names = { m for m in ms }
        return names

    def run(self):
        cur = db.cursor()
        findings = []
        for url in self.select_journals():
            logger.info("looking for author names on %s", url)
            for name in self.get_authornames(url):
                query = "INSERT INTO author_names (name, last_searched) VALUES (%s, NOW() - INTERVAL 1 YEAR)"
                try:
                    cur.execute(query, (name,))
                    db.commit()
                except pymysql.err.IntegrityError as e:
                    logger.info("{} already in db".format(name))
                    findings = [f for f in findings if f[0] != name]
                else:
                    logger.info("+++ new author name {}".format(name))
                    name_id = cur.lastrowid
                    findings.append((name, name_id, url))
        if findings:
            self.email(findings)

    def email(self, findings):
        body = ''
        for (name, name_id, url) in findings:
            body += "'{}' found on {}\n".format(name, url)
        try:
            sendmail('wo@umsu.de', '[PP] new author names', body)
            logger.info("mail sent")
        except Exception as e:
            logger.warning('failed to send email! %s', e)

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

    af = AuthorsFinder()
    af.run()
    
    sys.exit(0)
