#!/usr/bin/env python3
from opp import db
from opp.scraper import Doc
from opp.debug import debug
from .classifier import DocClassifier

clf = DocClassifier('data/philosophy.pk')
clf.load()

def evaluate(*docs):
   prob = clf.classify(*docs)
   if len(docs) > 1:
      debug(4, 'probability that documents are about philosophy: %s', ','.join(prob))
      return prob
   else:
      debug(4, 'probability that document is about philosophy: %s', prob)
      return prob

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
