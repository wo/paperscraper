import re
try:
    from .debug import debug, debuglevel
    from .util import request_url
except SystemError:
    # command line usage
    import os.path
    import sys
    curpath = os.path.abspath(os.path.dirname(__file__))
    libpath = os.path.join(curpath, os.path.pardir)
    sys.path.insert(0, libpath)
    from opp.debug import debug, debuglevel
    from opp.util import request_url

SEARCH_URL = 'https://philpapers.org/s/{}'

def get_publications(author_name, strict=False):
    """
    fetch list of publications (title, year) for <author_name> from philpapers.
    If <strict>, returns only exact matches for author_name, otherwise allows
    for name variants (e.g., with/without middle initial).
    """
    url = SEARCH_URL.format(author_name)
    debug(3, url)
    status,r = request_url(url)
    if status != 200:
        debug(1, "{} returned status {}".format(url, status))
        return []
    debug(5, r.text)
    if "class='entry'>" not in r.text:
        debug(3, "no results!")
        return []
    
    def name_match_strict(found_name):
        return author_name == found_name

    def name_match_nonstrict(found_name):
        n1parts = author_name.split()
        n2parts = found_name.split()
        # last names must match:
        if n1parts[-1] != n2parts[-1]:
            return False
        # return True if first names also match:
        if n1parts[0] == n2parts[0]:
            return True
        # check if one first name is matching initial:
        if len(n1parts[0]) <= 2 or len(n2parts[0]) <= 2:
            if n1parts[0][0] == n2parts[0][0]:
                return True
        return False

    name_match = name_match_strict if strict else name_match_nonstrict

    results = []
    for recordhtml in r.text.split("class='entry'>")[1:]:
        m = re.search("class='articleTitle[^>]+>([^<]+)</span>", recordhtml)
        if not m:
            continue
        title = m.group(1)
        if len(title) > 255:
           title = title[:251]+'...'
        ms = re.findall("class='name'>([^<]+)</span>", recordhtml)
        authors = [m for m in ms]
        m = re.search('class="pubYear">([^<]+)</span>', recordhtml)
        year = m.group(1) if m and m.group(1).isdigit() else None
        debug(4, '{}: {} ({})'.format(authors, title, year))
        if any(name_match(name) for name in authors):
            debug(4, 'author matches')
            results.append((title, year))
        else:
            debug(4, 'no author match')

    return results
        
if __name__ == "__main__":

    # for testing and debugging
    import argparse
    import logging
    logger = logging.getLogger('opp')
    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG)
    logger.addHandler(ch)

    ap = argparse.ArgumentParser()
    ap.add_argument('-v', '--verbose', action='store_true', help='turn on debugging output')
    ap.add_argument('name')
    args = ap.parse_args()
    
    if args.verbose:
        debuglevel(5)

    pubs = get_publications(args.name)
    print('{} publications'.format(len(pubs)))
    for (t,y) in pubs:
        print('{} ({})'.format(t,y))
        
