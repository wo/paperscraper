import sys
import re
import logging
import findmodules
import datetime
import math
import smtplib
import MySQLdb
from email.mime.text import MIMEText
from opp import db, util

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler(sys.stdout)
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)

class AuthorsFinder:

    journals = [
        'http://philpapers.org/pub/2563', # AJL
        'http://philpapers.org/pub/103', # AJP
        'http://philpapers.org/pub/158', # BJPS
        'http://philpapers.org/pub/53', # Analysis
        'http://philpapers.org/pub/120', # Behavioral and Brain Sciences
        'http://philpapers.org/pub/178', # Canadian Journal of Philosophy
        'http://philpapers.org/pub/283', # Dialectica
        'http://philpapers.org/pub/319', # Erkenntnis
        'http://philpapers.org/pub/324', # Ethical Theory and Moral Practice
        'http://philpapers.org/pub/325', # Ethics
        'https://philpapers.org/pub/10486', # Ergo
        'http://philpapers.org/pub/420', # Inquiry
        'http://philpapers.org/pub/568', # JPL
        'http://philpapers.org/pub/570', # JoP
        'http://philpapers.org/pub/647', # Linguistics and Philosophy
        'http://philpapers.org/pub/682', # Mind
        'http://philpapers.org/pub/733', # Nous
        'https://philpapers.org/pub/771', # Phil Imprint
        'http://philpapers.org/pub/774', # Philosophia Mathematica
        'http://philpapers.org/pub/795', # Phil Quarterly
        'http://philpapers.org/pub/798', # Phil Review
        'http://philpapers.org/pub/799', # Phil Studies
        'http://philpapers.org/pub/816', # PPR
        'http://philpapers.org/pub/819', # Philosophy and Public Affairs
        'http://philpapers.org/pub/822', # Phil Compass
        'http://philpapers.org/pub/827', # PoS
        'http://philpapers.org/pub/880', # Proceedings of the Arist Soc
        'http://philpapers.org/pub/1053', # Studies in Hist and PoS
        'http://philpapers.org/pub/1066', # Synthese
        'http://philpapers.org/pub/1091', # Theory and Decision
    ]

    def __init__(self):
        pass

    def select_journals(self):
        # if run as a daily cron job, cycles through the whole list once every week
        day = datetime.datetime.today().weekday()
        num = int(math.ceil(len(self.journals) / 7))
        num -= 1
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
            logger.debug("looking for author names on %s", url)
            for name in self.get_authornames(url):
                query = "INSERT INTO author_names (name, last_searched) VALUES (%s, '1970-01-01')"
                try:
                    cur.execute(query, (name,))
                    db.commit()
                except MySQLdb.IntegrityError:
                    logger.debug("{} already in db".format(name))
                    findings = [f for f in findings if f[0] != name]
                else:
                    logger.debug("+++ new author name {}".format(name))
                    name_id = cur.lastrowid
                    findings.append((name, name_id, url))
        if findings:
            self.sendmail(findings)

    def sendmail(self, findings):
        body = u''
        for (name, name_id, url) in findings:
            body += "'{}' found on {}\n".format(name, url)
            body += "Delete: http://www.philosophicalprogress.org/admin/website/authorname/{}/change/".format(name_id)
        msg = MIMEText(body, 'plain', 'utf-8')
        msg['Subject'] = '[new author names]'
        msg['From'] = 'Philosophical Progress <opp@umsu.de>'
        msg['To'] = 'wo@umsu.de'
        s = smtplib.SMTP('localhost')
        s.sendmail(msg['From'], [msg['To']], msg.as_string())
        s.quit()

if __name__ == "__main__":
    af = AuthorsFinder()
    af.run()

