#!/usr/bin/env python3
from doctyper.classifier import DocClassifier
import db
from scraper import Doc
from debug import debug

clf = DocClassifier('data/philosophy.pk')
clf.load()

def evaluate(*docs):
   probs = clf.classify(docs)
   if len(probs) > 1:
      debug(4, 'probability that documents are about philosophy: %s', ','.join(probs))
      return probs
   else:
      debug(4, 'probability that document is about philosophy: %s', probs[0])
      return probs[0]

def update():
    """
    re-train classifier; the training corpus is taken from the database.
    """
    debug(3, "re-training philosophy classifier")
    cur = db.dict_cursor()
    query = "SELECT cat_id FROM cats WHERE label=%s LIMIT 1"
    cur.execute(query, ('philosophy',))
    cat_id = cur.fetchall()[0]['cat_id']
    query = ("SELECT D.*, M.strength"
             " FROM docs D, docs2cats M"
             " WHERE M.doc_id = D.doc_id AND M.cat_id = %s AND M.is_training = 1")
    cur.execute(query, (cat_id,))
    debug(4, cur._last_executed)
    rows = cur.fetchall()
    if not rows:
        raise Exception('no training documents for philosophy classifier')
    docs = [Doc(**row) for row in rows]
    classes = [row['strength'] for row in rows]
    clf.train(docs, classes)
    clf.save()

def is_ready():
    """
    True if filter is trained
    """
    return clf.ready == True
