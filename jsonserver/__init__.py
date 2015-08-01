import pprint
import logging.handlers
from datetime import datetime, timedelta
import itertools
from collections import defaultdict
import re
import sys
from cStringIO import StringIO
from os.path import abspath, dirname, join
import MySQLdb.cursors
from flask import Flask, request, g, jsonify 
from flask.ext.mysql import MySQL

# access perl config file 'config.pl'
config_cache = {}
config_file = join(abspath(dirname(__file__)), '../config.pl')
def config(key):
    if key not in config_cache:
        if 'perlstr' not in config_cache:
            config_cache['_perlstr'] = open(config_file).read()
        m = re.search(key+"\s+=>\s'?(.+?)'?,", config_cache['_perlstr'])
        if m:
            config_cache[key] = m.group(1)
        else:
            config_cache[key] = ''
    return config_cache[key]

app = Flask(__name__)

app.config['DEBUG'] = True
app.logger.setLevel(logging.DEBUG)
logfile = join(abspath(dirname(__file__)), 'data/server.log')
handler = logging.FileHandler(logfile)
app.logger.addHandler(handler)

app.config['MYSQL_DATABASE_HOST'] = 'localhost'
app.config['MYSQL_DATABASE_USER'] = config('MYSQL_USER')
app.config['MYSQL_DATABASE_PASSWORD'] = config('MYSQL_PASS')
app.config['MYSQL_DATABASE_DB'] = config('MYSQL_DB')
app.config['MIN_CONFIDENCE'] = config('CONFIDENCE_THRESHOLD')
app.config['MAX_SPAM'] = config('MAX_SPAM')
app.config['DOCS_PER_PAGE'] = 20

mysql = MySQL()
mysql.init_app(app)

def get_db():
    if not hasattr(g, 'db'):
        g.db = mysql.connect()
    return g.db

@app.teardown_appcontext
def db_disconnect(exception=None):
    if hasattr(g, 'db'):
        g.db.close()

@app.before_request
def log_request():
    app.logger.info("\n".join([
        "\n=====",
        str(datetime.now()),
        request.url,
        request.method,
        request.remote_addr]))

@app.route("/doclist")
def doclist():
    offset = int(request.args.get('start') or 0)
    docs = get_docs('''SELECT D.doc_id, D.authors, D.title, D.abstract, D.url, D.filetype,
                       D.found_date, D.numwords, D.source_url, D.source_name, D.meta_confidence,
                       GROUP_CONCAT(T.label) AS topic_labels,
                       GROUP_CONCAT(T.topic_id) AS topic_ids,
                       GROUP_CONCAT(COALESCE(M.strength, -1)) AS strengths
                       FROM (docs D CROSS JOIN
                             (SELECT * FROM topics WHERE is_default = 1) AS T)
                       LEFT JOIN docs2topics M ON (D.doc_id = M.doc_id AND M.topic_id = T.topic_id) 
                       GROUP BY D.doc_id
                       ORDER BY D.found_date DESC
                    ''', offset=offset)
    return jsonify({ 'msg': 'OK', 'docs': docs })

@app.route('/feedlist')
def feedlist():
    num_days = 7
    start_date = (datetime.today() - timedelta(days=num_days)).strftime('%Y-%m-%d')
    docs = get_docs('''SELECT doc_id, authors, title, abstract, url, filetype,
                       numwords, source_url, source_name, found_date,
                       DATE_FORMAT(found_date, '%d %M %Y') AS found_day
                       FROM docs
                       WHERE found_date < CURDATE() AND found_date >= '{0}'
                       ORDER BY found_date DESC
                    '''.format(start_date), limit=200)
    return jsonify({ 'msg': 'OK', 'docs': docs })

@app.route("/topiclist/<topic>")
def topiclist(topic):
    min_p = float(request.args.get('min') or 0.5)
    # Get latest documents classified into <topic> or not yet
    # classified for <topic> at all, classify the unclassified ones,
    # and keep getting more documents until we have DOCS_PER_PAGE
    # many:
    rows = []
    offset = int(request.args.get('start') or 0)
    limit = app.config['DOCS_PER_PAGE']
    topic_id = 0
    while True:
        query = '''SELECT D.doc_id, M.strength, T.label, T.topic_id
                   FROM (docs D CROSS JOIN
                         (SELECT * FROM topics WHERE label='{0}') AS T)
                   LEFT JOIN docs2topics M ON (D.doc_id = M.doc_id AND M.topic_id = T.topic_id)
                   WHERE strength >= {1} OR strength IS NULL
                   ORDER BY D.found_date DESC
                   LIMIT {2} OFFSET {3}
                '''.format(topic, min_p, limit, offset)
        app.logger.debug(query)
        cur = get_db().cursor(MySQLdb.cursors.DictCursor)
        cur.execute(query)
        batch = cur.fetchall()
        if not batch: # no more docs in DB
            break
        topic_id = batch[0]['topic_id']
        rows += [row for row in batch if row['strength'] >= min_p]
        unclassified = [row for row in batch if row['strength'] is None]
        if unclassified:
            app.logger.debug("{} unclassified docs".format(len(unclassified)))
            add_content(unclassified)
            probs = classify(unclassified, batch[0]['label'], topic_id)
            for i,p in enumerate(probs):
                unclassified[i]['strength'] = p
            rows += [row for row in unclassified if row['strength'] >= min_p]
            rows = sorted(rows, key=lambda r:r['doc_id'], reverse=True)
        if len(rows) >= app.config['DOCS_PER_PAGE']:
            rows = rows[:app.config['DOCS_PER_PAGE']]
            break
        # Previously unclassified entries are now classified, so to
        # get further candidates from DB, we need to look past the
        # first len(doc) matches to the above query:
        offset += len(rows)
        app.logger.debug("retrieving more docs")
    
    # Now retrieve full docs and all topic values:
    docs = []
    if rows:
        doc_ids = [str(row['doc_id']) for row in rows]
        docs = get_docs('''SELECT D.doc_id, D.authors, D.title, D.abstract, D.url, D.filetype,
                           D.found_date, D.numwords, D.source_url, D.source_name, D.meta_confidence,
                           GROUP_CONCAT(T.label) AS topic_labels,
                           GROUP_CONCAT(T.topic_id) AS topic_ids,
                           GROUP_CONCAT(COALESCE(M.strength, -1)) AS strengths
                           FROM (docs D CROSS JOIN
                                 (SELECT * FROM topics WHERE is_default = 1) AS T)
                           LEFT JOIN docs2topics M ON (D.doc_id = M.doc_id AND M.topic_id = T.topic_id) 
                           WHERE D.doc_id IN ('{0}')
                           GROUP BY D.doc_id
                           ORDER BY D.found_date DESC
                        '''.format("','".join(doc_ids)))
        # add 'strength' parameter:
        for i,doc in enumerate(docs):
            doc['strength'] = "{0:.2f}".format(rows[i]['strength'])

    return jsonify({ 'msg': 'OK', 'docs': docs, 'topic_id': topic_id })

@app.route('/edit-source', methods=['POST'])
def editsource():
    source_type = int(request.form['type'])
    url = request.form['url']
    default_author = request.form['default_author']
    source_name = request.form['name']
    db = get_db()
    cur = db.cursor()
    query = '''INSERT INTO sources (url, status, type, default_author, name)
               VALUES(%s, 0, %s, %s, %s)
               ON DUPLICATE KEY UPDATE type=%s, default_author=%s, name=%s'''
    app.logger.debug(','.join((query,url,source_type,default_author,source_name)))
    cur.execute(query, (url,source_type,default_author,source_name,source_type,default_author,source_name))
    db.commit()
    insert_id = cur.lastrowid

    if source_type == 3:
        # register new blog subscription on superfeedr:
        from superscription import Superscription
        ss = Superscription(config('SUPERFEEDR_USER'), token=config('SUPERFEEDR_TOKEN'))
        r = ss.subscribe(
            hub_topic=url,
            hub_callback=request.url_root+'new_blog_post/'+insert_id)
        if not r or r.status_code != 203:
            return jsonify({'msg':'could not register blog on superfeedr!'})

    return jsonify({'msg':'OK'})


@app.route('/editdoc', methods=['POST'])
def editdoc():
    doc_id = request.form['doc_id']
    url = request.form['doc_url']
    opp_doc = True if request.form['oppdocs'] else False
    authors = request.form['authors']
    title = request.form['title']
    abstract = request.form['abstract']
    db = get_db()
    cur = db.cursor()
    if request.form['submit'] == 'Discard Entry':
        if opp_doc:
            query = "UPDATE locations SET spamminess=1 WHERE url=%s"
            app.logger.debug(','.join((query,url)))
            cur.execute(query, (url,))
        else:
            query = "DELETE FROM docs WHERE doc_id=%s"
            app.logger.debug(','.join((query,doc_id)))
            cur.execute(query, (doc_id,))
        db.commit()
    else:
        if opp_doc:
            # Problem: the opp documents table does not store the full
            # document text, so we need to reprocess the url with opp; to
            # enforce that, we set status=0 -- process_links.pl will then
            # add the record to the oppweb docs table (and it won't
            # overwrite metadata set with confidence=1).
            query = "UPDATE locations SET status=0 WHERE url=%s"
            app.logger.debug(query+','+url)
            cur.execute(query, (url,))
            db.commit()
            query = '''
                    UPDATE documents SET authors=%s, title=%s, abstract=%s, meta_confidence=1
                    WHERE document_id=%s
                    '''
        else:
            query = '''
                    UPDATE docs SET authors=%s, title=%s, abstract=%s, meta_confidence=1
                    WHERE doc_id=%s
                    '''
        app.logger.debug(','.join((query,authors,title,abstract,doc_id)))
        cur.execute(query, (authors, title, abstract, doc_id))
        db.commit()
    return jsonify({'msg':'OK'})

@app.route("/train")
def train():
    username = request.args.get('user')
    topic_id = int(request.args.get('topic_id'))
    doc_id = int(request.args.get('doc'))
    hamspam = int(request.args.get('class'))
    db = get_db()
    cur = db.cursor()
    # check if user is allowed to train this classifier:
    if username != 'wo':
        query = "SELECT label FROM topics WHERE topic_id = %s LIMIT 1"
        cur.execute(query, (topic_id,))
        rows = cur.fetchall()
        if not rows or (rows[0][0] != username):
            app.logger.info(rows[0])
            app.logger.info('{0} not allowed to train {1}'.format(username, topic_id))
            return jsonify({ 'msg':'user not allowed to train classifier' })
    query = '''
        INSERT INTO docs2topics (doc_id, topic_id, strength, is_training)
        VALUES ({0},{1},{2},1)
        ON DUPLICATE KEY UPDATE strength={2}, is_training=1
    '''
    query = query.format(doc_id, topic_id, hamspam)
    app.logger.debug(query)
    cur.execute(query)
    db.commit()
    msg = update_classifier(topic_id)
    return jsonify({ 'msg':msg })

def update_classifier(topic_id):
    from classifier import BinaryClassifier, Doc
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    query = '''
         SELECT D.*, M.strength
         FROM docs D, docs2topics M
         WHERE M.doc_id = D.doc_id AND M.topic_id = {0} AND M.is_training = 1
         ORDER BY D.found_date DESC
         LIMIT 100
    '''
    app.logger.debug(query)
    cur.execute(query.format(topic_id))
    rows = cur.fetchall()
    docs = [Doc(row) for row in rows]
    classes = [row['strength'] for row in rows]
    msg = ''
    if (0 in classes and 1 in classes):
        with Capturing() as output:
            clf = BinaryClassifier(topic_id)        
            clf.train(docs, classes)
            clf.save()
        msg += '\n'.join(output)
        # We might reclassify all documents now, but we postpone this step
        # until the documents are actually displayed (which may be never
        # for sufficiently old ones). So we simply undefine the topic
        # strengths to mark that no classification has yet been made.
        query = "UPDATE docs2topics SET strength = NULL WHERE topic_id = {0} AND is_training < 1"
        app.logger.debug(query)
        cur.execute(query.format(topic_id))
        db.commit()
    else:
        msg = "classifier not yet ready because only positive or negative training samples"
    return msg

@app.route('/init_topic')
def init_topic():
    label = request.args.get('label') 
    db = get_db()
    cur = db.cursor()
    query = "INSERT INTO topics (label) VALUES (%s)"
    try:
        app.logger.info(query, label)
        cur.execute(query, (label,))
        db.commit()
    except:
        app.logger.warn("failed to insert %s", label)
        return jsonify({'msg': 'Failed'})
    return jsonify({'msg':'OK'})


def get_docs(select, offset=0, limit=app.config['DOCS_PER_PAGE']):
    query = "{0} LIMIT {1} OFFSET {2}".format(select, limit, offset)
    app.logger.debug(query)
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    cur.execute(query)
    docs = cur.fetchall()
    if not docs:
        return docs

    if 'topic_labels' in docs[0]:
        # set up dictionary for default topic values:
        for doc in docs:
            app.logger.debug("retrieved doc {}".format(doc['doc_id']))
            doc['topics'] = dict(zip(doc['topic_labels'].split(','), 
                                     map(float, doc['strengths'].split(','))))
            # unclassified topics have value -1 now (see COALESCE in query)
    
        # find unclassified docs:
        unclassified = {} # topic_id => [docs]
        topics = dict(zip(docs[0]['topic_ids'].split(','), docs[0]['topic_labels'].split(',')))
        for topic_id, topic in topics.iteritems():
            uncl = [doc for doc in docs if doc['topics'][topic] == -1]
            if uncl:
                unclassified[topic_id] = uncl

        # classify unclassified docs:
        if unclassified:
            app.logger.debug("unclassified documents in get_docs")
            uncl_docs = itertools.chain.from_iterable(unclassified.values())
            uncl_docs = dict((doc['doc_id'], doc) for doc in uncl_docs).values() # unique
            add_content(uncl_docs)
            for topic_id, doclist in unclassified.iteritems():
                probs = classify(doclist, topics[topic_id], topic_id)
                for i,p in enumerate(probs):
                    doclist[i]['topics'][topics[topic_id]] = p

    # prepare for display:
    docs = [prettify(doc) for doc in docs]
    if 'topic_labels' in docs[0]:
        for doc in docs:
            doc['topics'] = sorted(
                [(t,int(s*10)) for (t,s) in doc['topics'].iteritems() if s > 0.5],
                key=lambda x:x[1], reverse=True)

    return docs

def add_content(docs):
    # retrieve full content of documents:
    db = get_db()
    cur = db.cursor(MySQLdb.cursors.DictCursor)
    doc_ids = [str(doc['doc_id']) for doc in docs]
    query = "SELECT * FROM docs WHERE doc_id IN ('{0}')".format("','".join(doc_ids))
    app.logger.debug(query)
    cur.execute(query)
    rows = cur.fetchall()
    # keep previous dict keys in docs:
    docs_dict = dict((doc['doc_id'], doc) for doc in docs)
    for row in rows:
        doc = docs_dict[row['doc_id']]
        for k,v in row.iteritems():
            if k not in doc:
                doc[k] = v

def get_default_topics():
    if not hasattr(g, 'default_topics'):
        query = "SELECT topic_id, label FROM topics WHERE is_default=1"
        cur = get_db().cursor()
        cur.execute(query)
        g.default_topics = cur.fetchall()
    return g.default_topics

def classify(rows, topic, topic_id):
    from classifier import BinaryClassifier, Doc
    docs = [Doc(row) for row in rows]
    with Capturing() as output:
        clf = BinaryClassifier(topic_id)
        clf.load()
        probs = clf.classify(docs)
    app.logger.debug('\n'.join(output))
    db = get_db()
    cur = db.cursor()
    for i, (p_spam, p_ham) in enumerate(probs):
        app.logger.debug("doc {} classified for topic {}: {}".format(
            rows[i]['doc_id'], topic_id, p_ham))
        query = '''
            INSERT INTO docs2topics (doc_id, topic_id, strength)
            VALUES ({0},{1},{2})
            ON DUPLICATE KEY UPDATE strength={2}
        '''
        query = query.format(rows[i]['doc_id'], topic_id, p_ham)
        app.logger.debug(query)
        cur.execute(query)
        db.commit()
    return [p[1] for p in probs]

def prettify(doc):
    # Adds and modifies some values of document objects retrieved from
    # DB for pretty display
    doc['source_url'] = doc['source_url'].replace('&','&amp;')
    doc['short_url'] = short_url(doc['url'])
    doc['source_name'] = doc['source_name'].replace('&','&amp;')
    doc['filetype'] = doc['filetype'].upper()
    doc['reldate'] = relative_date(doc['found_date'])
    doc['deltadate'] = relative_date(doc['found_date'], 1)
    # remove keys that don't need to be transmitted to client:
    if 'content' in doc:
        del doc['content']
    return doc

def short_url(url):
    if not url:
        return 'about:blank'
    url = re.sub(r'^https?://', '', url)
    if len(url) > 80:
        url = url[:38] + '...' + url[-39:]
    #url = re.sub(r'(\.\w+)$', r'<b>\1</b>', url)
    return url
    
def relative_date(time, diff=False):
    now = datetime.now()
    delta = now - time
    if diff:
        return int(delta.total_seconds())
    if delta.days > 730:
        return str(delta.days / 365) + "&nbsp;years ago"
    if delta.days > 60:
        return str(delta.days / 30) + "&nbsp;months ago"
    if delta.days > 14:
        return str(delta.days / 7) + "&nbsp;weeks ago"
    if delta.days > 1:
        return str(delta.days) + "&nbsp;days ago"
    if delta.days == 1:
        return "1&nbsp;day ago"
    if delta.seconds > 7200:
        return str(delta.seconds / 3600) + "&nbsp;hours ago"
    if delta.seconds > 3600:
        return "1&nbsp;hour ago"
    if delta.seconds > 119:
        return str(delta.seconds / 60) + "&nbsp;minutes ago"
    return "1&nbsp;minute ago"

class Capturing(list):
    # capture stdout
    def __enter__(self):
        self._stdout = sys.stdout
        sys.stdout = self._stringio = StringIO()
        return self
    def __exit__(self, *args):
        self.extend(self._stringio.getvalue().splitlines())
        sys.stdout = self._stdout

@app.route("/opp-queue")
def list_uncertain_docs():
    cur = mysql.connect().cursor(MySQLdb.cursors.DictCursor)
    query = '''
         SELECT
            D.*, D.document_id as doc_id,
            GROUP_CONCAT(L.location_id SEPARATOR ' ') as location_id,
            GROUP_CONCAT(L.url SEPARATOR ' ') as locs,
            GROUP_CONCAT(L.location_id SEPARATOR ' ') as loc_ids,
            GROUP_CONCAT(L.spamminess SEPARATOR ' ') as spamminesses,
            GROUP_CONCAT(S.url SEPARATOR ' ') as srcs,
            GROUP_CONCAT(S.name SEPARATOR '*') as src_names,
            MIN(L.filetype) as filetype,
            MIN(L.filesize) as filesize
         FROM
            documents D,
            locations L,
            sources S,
            links R
         WHERE
            D.document_id = L.document_id
            AND L.location_id = R.location_id
            AND S.source_id = R.source_id
            AND L.status = 1
            AND {0}
         GROUP BY D.document_id
         ORDER BY D.found_date DESC
         LIMIT {1}
         OFFSET {2}
    '''
    limit = app.config['DOCS_PER_PAGE']
    offset = int(request.args.get('start') or 0)
    max_spam = 0.3
    min_confidence = app.config['MIN_CONFIDENCE']
    where = "spamminess <= {0} AND meta_confidence <= {1}".format(max_spam, min_confidence)
    query = query.format(where, limit, offset)
    cur.execute(query)
    rows = cur.fetchall()
    for row in rows: 
        row['source_url'] = row['srcs'].split(' ')[0]
        row['source_name'] = row['src_names'].split('*')[0]
        row['url'] = row['locs'].split(' ')[0]
        row['loc_id'] = row['loc_ids'].split(' ')[0]
        row['spamminess'] = row['spamminesses'].split(' ')[0]
        row['numwords'] = row['length']
        row = prettify(row)
 
    return jsonify({ 'msg': 'OK', 'docs': rows })

@app.route("/sources")
def list_sources():
    cur = mysql.connect().cursor(MySQLdb.cursors.DictCursor)
    #query = 'SELECT * FROM sources WHERE parent_id IS NULL ORDER BY default_author'
    query = '''SELECT S.*, COUNT(document_id) AS num_papers
        FROM sources S
        LEFT JOIN links USING (source_id)
        LEFT JOIN locations L USING (location_id)
        LEFT JOIN documents D USING (document_id)
        WHERE D.document_id IS NULL OR (L.spamminess < 0.5 AND D.meta_confidence > 0.5)
        GROUP BY S.source_id
        ORDER BY S.default_author, S.name
    '''
    cur.execute(query)
    rows = cur.fetchall()

    return jsonify({ 'msg': 'OK', 'sources': rows })

if __name__ == "__main__":
    app.run()

