#!/usr/bin/env python3
import pytest
import db

def test_connect():
    conn = db.connection()
    assert conn is not None

def test_cursor():
    cur = db.cursor()
    query = "SHOW TABLES"
    cur.execute(query)
    tables = cur.fetchall()
    assert tables is not None

def test_query(caplog):
    cur = db.dict_cursor()
    query = "SELECT * FROM sources"
    #cur.execute(query, (url,))
    cur.execute(query)
    sources = cur.fetchall()
    assert True
