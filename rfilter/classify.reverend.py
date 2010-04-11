#!/usr/bin/python

import sys
import os.path
from reverend.thomas import Bayes

filename = sys.argv[1]
if (not os.path.isfile(filename)):
   print "file", filename, "not found."
   sys.exit()

fh = open(filename, "r")
text = fh.read()
fh.close()

classifier = Bayes()
classifier.load()
classifier.guess(text)
