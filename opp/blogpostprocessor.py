#!/usr/bin/env python3
import time, sys, re
from datetime import datetime
import requests
from opp import db
from opp.models import Doc, categories
from opp.debug import debug
from opp.docparser import blogpostparser
from opp.doctyper import classifier

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
    try:
        blogpostparser.parse(doc)
    except Exception as e:
        debug(1, "parser error %s", e)
        remove_from_db(doc)
        return 0
    if len(doc.content) < 500:
        debug(1, "content too short")
        remove_from_db(doc)
        return 0

    # estimate whether post is on philosophy:
    blogspamfilter = classifier.get_classifier('blogspam')
    try:
        doc.is_philosophy = 100 - int(blogspamfilter.classify(doc) * 100)
    except UntrainedClassifierException as e:
        doc.is_philosophy = 90
    if doc.is_philosophy < 5:
        debug(1, "spam: blogspam score %s > 95", 100 - doc.is_philosophy)
        remove_from_db(doc)
        return 0
        
    # flag for manual approval if dubious relevance:
    if doc.is_philosophy < 40:
        debug(1, "flagging for manual approval")
        doc.hidden = True

    # categorize:
    if doc.numwords > 700:
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
    try:
        cur.execute(query, (doc.doc_id,))
        debug(4, cur._last_executed)
        db.commit()
    except:
        # delete fails if blogpost url is a document that has also
        # been found by the scraper, because then there'll be a Link
        # to the doc.
        debug(1, "delete failed")
        pass
