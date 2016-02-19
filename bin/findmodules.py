import os.path
import sys

curpath = os.path.abspath(os.path.dirname(__file__))
libpath = os.path.join(curpath, os.path.pardir, 'opp')
sys.path.insert(0, libpath)
