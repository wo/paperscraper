#!/usr/bin/env python3
from os.path import abspath, dirname, join
import subprocess
from debug import debug, debuglevel

PERL = '/usr/bin/perl'
PATH = abspath(dirname(__file__))

def doctidy(xmlfile):
    cmd = [PERL, join(PATH, 'Doctidy.pm'), xmlfile]
    if debuglevel() > 4:
        cmd.insert(2, '-v')
    debug(2, ' '.join(cmd))
    try:
        stdout = subprocess.check_output(cmd, stderr=subprocess.STDOUT, timeout=10)
    except subprocess.CalledProcessError as e:
        debug(1, e.output)
        raise
    if debuglevel() > 4:
        debug(5, stdout.decode('utf-8'))
