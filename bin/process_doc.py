#!/usr/bin/env python3
import sys
import logging
import argparse
import findmodules
from opp import scraper
from opp import debug

"""
for debugging
"""

logger = logging.getLogger('opp')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler(sys.stdout)
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)

ap = argparse.ArgumentParser()
ap.add_argument('filename', help='file to process')
ap.add_argument('-d', '--debuglevel', default=1, type=int)
ap.add_argument('-k', '--keep', action='store_true', help='keep temporary files')
ap.add_argument('-u', '--url', type=str, help='link url')
ap.add_argument('-l', '--linkcontext', type=str, help='link context')
ap.add_argument('-a', '--anchortext', type=str, help='anchortext')
ap.add_argument('-s', '--sourcehtml', type=str, help='source page html')
args = ap.parse_args()

debug.debuglevel(args.debuglevel or 2)

# set up doc for processing:
filetype = 'pdf' if 'pdf' in args.filename else 'doc'
doc = scraper.Doc(filetype=filetype)
doc.link = scraper.Link(url=args.url or 'foo')
doc.link.context = args.linkcontext or 'foo'
doc.link.anchortext = args.anchortext or 'foo'
doc.source = scraper.Source(url='foo', html=(args.sourcehtml or 'foo'))
doc.tempfile = args.filename

# process
scraper.process_file(doc, keep_tempfiles=args.keep)
