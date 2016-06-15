#!/usr/bin/env python3
import time, sys, re
from datetime import datetime
import requests
from . import db
from .scraper import Doc, categories
from .debug import debug
from .docparser import blogpostparser
from .doctyper import classifier

def run():
    """
    retrieve and process new blog posts that have been put in the db
    by opp-web:feedhandler
    """
    cur = db.cursor()
    query = "SELECT doc_id FROM docs WHERE doctype = 'blogpost' AND status = 0"
    cur.execute(query)
    debug(4, cur._last_executed)
    posts = cur.fetchall()
    if not posts:
        return debug(3, "no new blog posts")
    for id in posts:
        post = Doc(doc_id=id)
        post.load_from_db()
        process_blogpost(post)

def process_blogpost(doc):
    """
    retrieve post info, check if philosophical content, classify
    """
    debug(1, "processing new blog post from %s", doc.source_name)
    blogpostparser.parse(doc)
    if len(doc.content) < 500:
        debug(1, "content too short")
        remove_from_db(doc)
        return 0

    # estimate whether post is on philosophy:
    philosophyfilter = classifier.get_classifier('philosophy')
    try:
        doc.is_philosophy = int(philosophyfilter.classify(doc) * 100)
    except UntrainedClassifierException as e:
        doc.is_philosophy = 90
    if doc.is_philosophy < 25 and False: # TODO: reactivate once philosophy filter works
        debug(1, "spam: philosophy score %s < 25", doc.is_philosophy)
        remove_from_db(doc)
        return 0
        
    # flag for manual approval if dubious relevance:
    if doc.is_philosophy < 60:
        debug(1, "flagging for manual approval")
        doc.hidden = True

    # categorize:
    for (cat_id, cat) in categories():
        clf = classifier.get_classifier(cat)
        try:
            strength = int(clf.classify(doc) * 100)
            debug(3, "%s score %s", cat, strength)
        except UntrainedClassifierException as e:
            continue 
        doc.assign_category(cat_id, strength)
   
    doc.found_date = datetime.now()
    doc.status = 1
    doc.update_db()

def remove_from_db(doc):
    cur = db.cursor()
    query = "DELETE FROM docs WHERE doc_id = %s"
    cur.execute(query, (doc.doc_id,))
    debug(4, cur._last_executed)
    db.commit()
