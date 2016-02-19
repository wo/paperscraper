#!/usr/bin/env python3
import logging
import re
import subprocess
from functools import lru_cache

PDFINFO = '/usr/bin/pdfinfo'

@lru_cache() # memoize
def pdfinfo(pdffile):
    cmd = [PDFINFO, pdffile]
    #debug(3, ' '.join(cmd))
    try:
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=2)
        output = output.decode('ascii')
    except subprocess.CalledProcessError as e:
        print(e.output)
        raise
    res = {}
    for line in output.split('\n'):
        if ':' in line:
            k,v = line.split(':', 1)
            res[k] = v.strip()
    return res
