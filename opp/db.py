#!/usr/bin/env python3
import MySQLdb
import MySQLdb.cursors
from config import config
import logging

_conn = None
_cur = None
_dictcur = None

def connection(host=config['mysql']['host'],
               db=config['mysql']['db'],
               user=config['mysql']['user'],
               passwd=config['mysql']['pass']):
    global _conn
    if not _conn or not _conn.open:
        _conn = MySQLdb.connect(host=host, db=db, user=user, passwd=passwd,
                                use_unicode=True, charset='UTF8')
    return _conn

def cursor():
    global _cur
    if not _cur:
        _cur = connection().cursor()
    return _cur

def dict_cursor():
    global _dictcur
    if not _dictcur:
        _dictcur = connection().cursor(MySQLdb.cursors.DictCursor)
    return _dictcur

def commit():
    global _conn
    _conn.commit()

def close():
    global _conn
    if _conn:
        _conn.close()
