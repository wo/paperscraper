#!/usr/bin/env python3
import smtplib
from email.mime.text import MIMEText
from .config import config
    
def sendmail(to, subject, body):

    msg = MIMEText(body, 'plain', 'utf-8')
    msg['Subject'] = subject
    msg['From'] = format(config['email']['from'])
    msg['To'] = to
    s = smtplib.SMTP_SSL(config['email']['smtp'], config['email']['port'])
    #s.set_debuglevel(1)
    s.ehlo()
    s.login(config['email']['user'], config['email']['pass'])
    s.sendmail(config['email']['from'], to, msg.as_string())
    s.quit()
