#!/usr/bin/env python3
import os.path
import sys
import json

curpath = os.path.abspath(os.path.dirname(__file__))
parpath = os.path.join(curpath, os.path.pardir)

with open(os.path.join(parpath, 'config.json')) as f:
    config = json.load(f)
