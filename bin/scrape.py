#!/usr/bin/env python3
import sys
import logging
import argparse
import findmodules
from opp import db, scraper, debug, browser

logger = logging.getLogger('opp')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler(sys.stdout)
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)

ap = argparse.ArgumentParser()
ap.add_argument('url', help='(part of) url of source page to scrape')
ap.add_argument('-d', '--debug_level', default=1, type=int)
ap.add_argument('-k', '--keep', action='store_true', help='keep temporary files')
ap.add_argument('-l', '--link', type=str, help='only process this link')
args = ap.parse_args()

debug.debuglevel(args.debug_level)

cur = db.dict_cursor()
query = "SELECT * FROM sources WHERE url LIKE %s LIMIT 1"
cur.execute(query, ('%'+args.url+'%',))
sources = cur.fetchall()
if not sources:
   raise Exception(args.url+' not in sources table')
source = scraper.Source(**sources[0])

if args.link:
    b = scraper.Browser()
    b.goto(source.url)
    source.set_html(b.page_source)
    try:
        el = b.find_element("xpath", "//a[contains(@href, '{}')]".format(args.link))
    except Exception as e:
        sys.exit('no link containing '+args.link+' on '+source.url)
    url = source.make_absolute(el.get_attribute('href'))
    li = scraper.Link(url=url, source=source, element=el)
    li.load_from_db()
    scraper.process_link(li, force_reprocess=True, keep_tempfiles=args.keep)
else:
    scraper.scrape(source, keep_tempfiles=args.keep)

browser.stop_browser()
