#! /usr/bin/env python

# Classify document

"""Usage: %(program)s <filename>

"""

import storage
from tokenizer import Tokenizer
from classifier import Classifier
from Options import options, get_pathname_option

import sys
import os.path

# read file into text variable:
filename = sys.argv[1]
if (not os.path.isfile(filename)):
   print "file", filename, "not found."
   sys.exit()
fh = open(filename, "r")
text = fh.read()
fh.close()

# set up classifier:
tokenizer = Tokenizer()
usedb = options["Storage", "persistent_use_database"]
pck = get_pathname_option("Storage", "persistent_storage_file")
classifier = storage.open_storage(pck, usedb, 'c')

# go:
tokens = tokenizer.tokenize(text)
spamprob = classifier.spamprob(tokens)
print 'spamprob:',spamprob

