#!/usr/bin/env python3
import os.path
import sys
from os import listdir
import re

sys.path.append('..')
from pdf2xml import pdf2xml

pdfs = [f for f in listdir('.') if re.search('.pdf$', f)]

for pdf in pdfs:
    print(pdf)
    try:
        pdf2xml.pdf2xml(pdf, pdf+'.xml')
    except Exception as e:
        print(str(e))
