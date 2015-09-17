import MySQLdb as mdb
import sys
import re
from os.path import abspath, dirname, join
import smtplib
from email.mime.text import MIMEText
from config import config

# connect to db:
db = mdb.connect('localhost', config('MYSQL_USER'), config('MYSQL_PASS'), config('MYSQL_DB'))
cur = db.cursor(mdb.cursors.DictCursor)

# get last doc_id for which a notification was sent:
last_id_file = join(abspath(dirname(__file__)), '.email_notifications_last_id')
try:
    with open(last_id_file, 'r') as f:
        last_id = int(f.read())
except IOError:
    cur.execute("SELECT doc_id FROM docs ORDER BY doc_id DESC LIMIT 1")
    row = cur.fetchall()
    last_id = row[0]['doc_id']
    with open(last_id_file, 'w') as f:
        f.write(str(last_id))
    sys.exit(0)

# check for more recent docs, one at a time:
cur.execute("SELECT * FROM docs WHERE doc_id > %s ORDER BY doc_id ASC LIMIT 1", (last_id,))
row = cur.fetchall()
if not row:
    sys.exit(0)

# send email notification:
doc = row[0]
flag = 'blogpost' if doc['filetype'] == 'blogpost' else 'paper'
if doc['status'] == 0:
    flag += '?'
subject = '[{}] {authors}: {title}'.format(flag, **doc)

body = '''

doc_id: {doc_id}
status: {status}
meta_confidence: {meta_confidence} 
spamminess: {spamminess}

{authors}:
{title} [{filetype}]
{url}

{abstract}

Found {found_date} on {source_name} 
{source_url}

Edit/Delete: http://umsu.de/opp/edit-doc?doc_id={doc_id}

'''.format(**doc)

msg = MIMEText(body)
msg['Subject'] = subject
msg['From'] = 'Philosophical Progress <opp@umsu.de>'
msg['To'] = 'wo@umsu.de'

#print msg.as_string()

s = smtplib.SMTP('localhost')
s.sendmail(msg['From'], [msg['To']], msg.as_string())
s.quit()

# store doc_id for which a notification was sent:
with open(last_id_file, 'w') as f:
    f.write(str(doc['doc_id']))
    
