#!/usr/bin/env python3
import os.path
import sys

curpath = os.path.abspath(os.path.dirname(__file__))
libpath = os.path.join(curpath, os.path.pardir, 'opp')
sys.path.insert(0, libpath)
# Why do I have to do this??
libpath2 = os.path.join(curpath, os.path.pardir, 'opp', 'docparser')
sys.path.insert(0, libpath2)
