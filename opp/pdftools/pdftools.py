#!/usr/bin/env python3
import logging
import re
import os
import shutil
import tempfile
import subprocess
from functools import lru_cache
from ..debug import debug

PDFINFO = '/usr/bin/pdfinfo'
PDFSEPARATE = '/usr/bin/pdfseparate'
GS = '/usr/bin/gs'
PERL = '/usr/bin/perl'

logger = logging.getLogger('opp')

def tempdir():
    if not hasattr(tempdir, 'dirname'):
        tempdir.dirname = tempfile.mkdtemp()
        debug(2, "creating temporary directory: %s", tempdir.dirname)
    return tempdir.dirname

def remove_tempdir():
    if hasattr(tempdir, 'dirname'):
        shutil.rmtree(tempdir())
        del tempdir.dirname

@lru_cache() # memoize
def pdfinfo(filename):
    '''returns dictionary of pdfinfo (poppler) data'''
    cmd = [PDFINFO, filename]
    debug(3, ' '.join(cmd))
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

def pdfcut(filename, newfilename, pageranges, keep_tempfiles=False):
    '''
    extracts certain pages from filename and puts them into
    newfilename. pageranges is a list of ranges, e.g. [(1,3),
    (12,12), (15,16)] would extract pages 1,2,3,12,15,16.
    '''
    tempbase = os.path.join(tempdir(), os.path.basename(filename))
    pagepattern = tempbase + '%d.pdf'
    pagefiles = []
    for (start, end) in pageranges:
        cmd = [PDFSEPARATE, '-f', str(start), '-l', str(end), filename, pagepattern]
        debug(3, ' '.join(cmd))
        try:
            subprocess.check_call(cmd, timeout=20)
            pagefiles.extend([tempbase+str(i)+'.pdf' for i in range(start, end+1)])
        except Exception as e:
            debug(1, 'pdfseparate failed to split pdf! %s', e.output)
            if not keep_tempfiles:
                debug(3, "removing temporary directory")
                remove_tempdir()
            raise
    if pagefiles:
        cmd = [GS, '-dBATCH', '-dNOPAUSE', '-q', '-sDEVICE=pdfwrite', '-dPDFSETTINGS=/prepress', 
               '-sOutputFile='+newfilename] + pagefiles
        debug(3, ' '.join(cmd))
        try:
            subprocess.check_call(cmd, timeout=20)
        except Exception as e:
            debug(1, 'gs failed to merge pdfs! %s', e.output)
            raise
        finally:
            if not keep_tempfiles:
                debug(3, "removing temporary directory")
                remove_tempdir()
