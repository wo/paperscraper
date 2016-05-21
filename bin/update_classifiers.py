#!/usr/bin/env python3
import sys
import logging
import findmodules
from opp import db, debug
from opp.doctyper import classifier

logger = logging.getLogger('opp')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler(sys.stdout)
ch.setLevel(logging.DEBUG)
logger.addHandler(ch)

debug.debuglevel(4)

cur = db.cursor()
query = ("SELECT label FROM cats")
cur.execute(query)
for row in cur.fetchall():
   classifier.update_classifier(row[0])
