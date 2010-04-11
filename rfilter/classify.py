#!/usr/bin/python

from tokenizer import Tokenizer
from classifier import Classifier

import sys
import os.path

filename = sys.argv[1]
if (not os.path.isfile(filename)):
   print "file", filename, "not found."
   sys.exit()

fh = open(filename, "r")
text = fh.read()
fh.close()

tokenizer = Tokenizer()
tokens = tokenizer.tokenize(text)

classifier = Classifier()
spamprob = classifier.spamprob(tokens)
print "spamprob: ", spamprob
