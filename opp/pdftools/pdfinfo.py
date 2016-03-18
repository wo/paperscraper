#!/usr/bin/env python3
import logging
import re
import subprocess
import logging
from functools import lru_cache

PDFINFO = '/usr/bin/pdfinfo'

logger = logging.getLogger('opp')

@lru_cache() # memoize
def pdfinfo(pdffile):
    cmd = [PDFINFO, pdffile]
    #logger.debug(' '.join(cmd))
    try:
        output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=2)
        output = output.decode('utf-8')
    except subprocess.CalledProcessError as e:
        logger.warn(e.output)
        raise
    res = {}
    for line in output.split('\n'):
        if ':' in line:
            k,v = line.split(':', 1)
            res[k] = v.strip()
    return res
