#!/usr/bin/env python3
import MySQLdb
import MySQLdb.cursors
from .config import config
import logging

_conn = None

def connect(host=config['mysql']['host'],
            db=config['mysql']['db'],
            user=config['mysql']['user'],
            passwd=config['mysql']['pass']):
    global _conn
    if not _conn or not _conn.open:
        _conn = MySQLdb.connect(host=host, db=db, user=user, passwd=passwd,
                                use_unicode=True, charset='UTF8')
    return _conn

def cursor(use_dict=False, retry=False):
    # not cached so we can reconnect if db connection is gone
    try:
        if use_dict:
            cursor = connect().cursor(MySQLdb.cursors.DictCursor)
        else:
            cursor = connect().cursor()
            cursor.execute("SET NAMES utf8mb4")
            cursor.execute("SET CHARACTER SET utf8mb4")
            cursor.execute("SET character_set_connection=utf8mb4")
        return cursor
    except:
        # Lost connection to MySQL server
        if not retry:
            global _conn
            _conn = None
            return cursor(use_dict=use_dict, retry=True)
        else:
            raise

def dict_cursor():
    return cursor(use_dict=True)

def commit():
    global _conn
    _conn.commit()

def close():
    global _conn
    if _conn:
        _conn.close()
