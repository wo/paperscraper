#! /usr/bin/env python

# Untrain categorizer on document

"""Usage: %(program)s <filename> <is_spam>

Where is_spam is true or false

"""

import storage
from tokenizer import Tokenizer
from classifier import Classifier
from Options import options, get_pathname_option

import sys
import os.path

filename = sys.argv[1]
if (sys.argv[2] == 'true' or sys.argv[2] == '1'):
   is_spam = True
else:
   is_spam = False

# read file into text variable:
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
classifier.unlearn(tokens, is_spam)
classifier.store()

