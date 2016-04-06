#!/usr/bin/env python3
import re
from statistics import median
from scipy.stats import nbinom
import sys, os.path
curpath = os.path.abspath(os.path.dirname(__file__))
libpath = os.path.join(curpath, os.path.pardir)
sys.path.insert(0, libpath)
from subjectivebayes import BinaryNaiveBayes
from debug import debug, debuglevel

def evaluate(doc):
    debug(4, 'trying to guess document type')
    probs = {
        'book': bookfilter.test(doc, debug=debuglevel()>3, smooth=False),
        'chapter': chapterfilter.test(doc, debug=debuglevel()>3, smooth=True),
        'thesis': thesisfilter.test(doc, debug=debuglevel()>3, smooth=False),
        'review': reviewfilter.test(doc, debug=debuglevel()>3, smooth=True)
    }
    debug(2, 'doctyper: %s', ', '.join(['{} {}'.format(k,v) for k,v in probs.items()]))
    if max(probs.values()) > 0.5:
        return max(probs, key=probs.get)
    else:
        return 'article'

# =========================================================================

def length(doc):
    return doc.numwords
    
def in_context(string):
    def check(doc):
        if not doc.link.context:
            return Ellipsis
        return string in doc.link.context.lower()
    return check

def in_beginning(regex):
    reg = re.compile(regex, re.I)
    def check(doc):
        if not doc.content:
            return Ellipsis
        beginning = doc.content[:5000]
        return reg.search(beginning)
    return check


# =========================================================================

bookfilter = BinaryNaiveBayes(prior_yes=0.2)

bookfilter.likelihood('numwords', length, 
                      p_ifyes=nbinom(7, 0.0001), p_ifno=nbinom(1, 0.0001))

# TODO: add more features? "Acknowledgements" section? Occurrences of
# "this book" TOC? Index? ...

# =========================================================================

chapterfilter = BinaryNaiveBayes(prior_yes=0.2)

chapterfilter.likelihood('numwords', length, 
                         p_ifyes=nbinom(2, 0.0002), p_ifno=nbinom(3, 0.0002))

chapterfilter.likelihood('"chapter" occurs in link context', in_context('chapter'),
                         p_ifyes=0.7, p_ifno=0.05)

# TODO: add features?

# =========================================================================

thesisfilter = BinaryNaiveBayes(prior_yes=0.2)

thesisfilter.likelihood('numwords', length, 
                      p_ifyes=nbinom(7, 0.0001), p_ifno=nbinom(1, 0.0001))

thesisfilter.likelihood('"thesis" occurs in link context', in_context('thesis'),
                        p_ifyes=0.7, p_ifno=0.05)

# TODO: add features!

# =========================================================================

reviewfilter = BinaryNaiveBayes(prior_yes=0.15)

reviewfilter.likelihood('numwords', length, 
                         p_ifyes=nbinom(2, 0.0003), p_ifno=nbinom(3, 0.0002))

reviewfilter.likelihood('"review of" occurs in link context', in_context(r'review of'),
                        p_ifyes=0.8, p_ifno=0.03)

reviewfilter.likelihood('beginning contains "review"', in_beginning(r'\breview'),
                        p_ifyes=0.6, p_ifno=0.08)

reviewfilter.likelihood('beginning contains "press"', in_beginning(r' Press\b'),
                        p_ifyes=0.6, p_ifno=0.05)

reviewfilter.likelihood('beginning contains "hardcover"', in_beginning(r'\bhardcover'),
                        p_ifyes=0.4, p_ifno=0.03)

reviewfilter.likelihood('beginning contains "ISIN"', in_beginning(r'[\d\s]{12}'),
                        p_ifyes=0.4, p_ifno=0.05)

reviewfilter.likelihood('beginning contains pages info', in_beginning(r'\b\d{3,4}(?: ?pp| pages)'),
                        p_ifyes=0.4, p_ifno=0.04)
    

# =========================================================================

if __name__ == '__main__':
    # graphical output for choosing distributions
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('classifier', help='name of classifier')
    ap.add_argument('condition', help='name of likelihood condition')
    args = ap.parse_args()

    cl = globals()[args.classifier]
    for li in cl.likelihoods:
        if li[0] == args.condition:
            break
    else:
        raise Exception('condition not found')
    p_ifyes, p_ifno = li[2], li[3]

    import matplotlib.pyplot as plt
    import numpy as np
    x = np.arange(min(p_ifyes.ppf(0.01), p_ifno.ppf(0.01)), 
                  max(p_ifyes.ppf(0.99), p_ifno.ppf(0.99)))
    fig, ax = plt.subplots()
    plt.plot(x, p_ifyes.pmf(x), c='green')
    plt.plot(x, p_ifno.pmf(x), c='red')
    plt.show()
