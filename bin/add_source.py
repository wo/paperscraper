#!/usr/bin/env python3
import sys
import logging
import argparse
import findmodules
from opp.models import Source

'''
This script is to be run from the command line for debugging
purposes only.
'''

ap = argparse.ArgumentParser()
ap.add_argument('url', help='url of source page')
ap.add_argument('-n', '--default_author', type=str)
ap.add_argument('-t', '--source_type', type=str)
args = ap.parse_args()

source = Source(
    url=args.url,
    default_author=args.default_author if args.default_author else '',
    source_type=args.source_type if args.source_type else 'personal',
)
source.save_to_db()
print('source saved as id {}'.format(source.source_id))
