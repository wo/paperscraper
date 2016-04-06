#!/usr/bin/env python3
import re
from statistics import median
from scipy.stats import nbinom
#import sys, os.path
#curpath = os.path.abspath(os.path.dirname(__file__))
#libpath = os.path.join(curpath, os.path.pardir)
#sys.path.insert(0, libpath)
from subjectivebayes import BinaryNaiveBayes
from debug import debug, debuglevel

"""
classifier to evaluate whether a pdf/word document is a paper (or
book etc.), as opposed to a handout, a cv, lecture slides etc.
"""

classifier = BinaryNaiveBayes(prior_yes=0.6)

def bad_url(doc):
    pat = re.compile(r'\bcours|\blecture|\btalk|handout|teaching')
    return pat.search(doc.url.lower())
classifier.likelihood('bad url', bad_url, p_ifyes=0.05, p_ifno=0.2)

def bad_anchortext(doc):
    pat = re.compile(r'^site\s*map$|^home|page\b|\bslides\b|handout')
    return pat.search(doc.link.anchortext.lower())
classifier.likelihood('bad anchortext', bad_anchortext, p_ifyes=0.01, p_ifno=0.3)

def good_linkcontext(doc):
    pat = re.compile(r'penultimate|draft|forthcoming')
    return pat.search(doc.link.context.lower())
classifier.likelihood('good link context', good_linkcontext, p_ifyes=0.5, p_ifno=0.05)

def course_words(doc):
    pat = re.compile(r'\bcourse|seminar|schedule|readings|textbook|students|\bpresentation|handout|essay|\bweek|hours/', re.I) 
    # normalize all measures to 10000 word documents (i.e., here we
    # return the number of matches per 10000 words):
    return int(len(pat.findall(doc.content)) * 10000 / doc.numwords)
classifier.likelihood('course note words', course_words,
                      p_ifyes=nbinom(1, 0.8), p_ifno=nbinom(2, 0.2))

def paper_words(doc):
    pat = re.compile(r'in section|finally,', re.I)
    return int(len(pat.findall(doc.content)) * 10000 / doc.numwords)
classifier.likelihood('typical paper words', paper_words,
                      p_ifyes=nbinom(2, 0.3), p_ifno=nbinom(1, 0.6))

def interview_words(doc):
    pat = re.compile(r'interview|do you', re.I)
    return int(len(pat.findall(doc.content)) * 10000 / doc.numwords)
classifier.likelihood('interview words', interview_words,
                      p_ifyes=nbinom(1, 0.8), p_ifno=nbinom(1, 0.2))

def verbs(doc):
    # bibliographies and other lists don't contain many verbs
    return int(len(re.findall(r'\bis\b', doc.content)) * 10000 / doc.numwords)
classifier.likelihood('verbs', verbs, 
                      p_ifyes=nbinom(30, .1), p_ifno=nbinom(2, 0.01))

def length(doc):
    return doc.numwords
classifier.likelihood('numwords', length, 
                      p_ifyes=nbinom(3, 0.0002), p_ifno=nbinom(1, 0.0002))

def contains_bib(doc):
    pat = re.compile(r'(?:\breferences|bibliography|\ws\s+cited)(?:</\w>|\s)*\n', re.I)
    return pat.search(doc.content)
classifier.likelihood('contains bibliography', contains_bib, p_ifyes=0.8, p_ifno=0.2)

def line_length(doc):
    # short lines indicates presentation slides
    linelengths = [len(l) for l in doc.content.split('\n')]
    return int(median(linelengths))
classifier.likelihood('median line length', line_length, 
                      p_ifyes=nbinom(3, 0.03), p_ifno=nbinom(2, 0.04))

def words_per_page(doc):
    # few words indicates presentation slides
    if doc.numpages < 2:
        return Ellipsis
    return int(doc.numwords / doc.numpages)
classifier.likelihood('words per page', words_per_page, 
                      p_ifyes=nbinom(4, 0.01), p_ifno=nbinom(3, 0.01))

def many_linegaps(doc):
    # indicates handouts
    """ here we need pdf extractor info! xxx """
    pass
    """
    my $gaps = 1;
    my $nogaps = 0;
    my $startpage = int($loc->{extractor}->{numpages}/10);
    foreach my $ch (@{$loc->{extractor}->{chunks}}) {
        next if $ch->{page}->{number} < $startpage;
        last if $ch->{page}->{number} > $startpage + 2;
        next unless $ch->{prev} && $ch->{next};
                my $gap_above = ($ch->{top} - $ch->{prev}->{bottom});
        my $gap_below = ($ch->{next}->{top} - $ch->{bottom});
        if (abs($gap_above - $gap_below) > $ch->{height}/4) {
            #print "xxx gaps $gap_above-$gap_below around ",$ch->{text},"\n";
            $gaps++;
        }
        else {
            $nogaps++;
        }
    }
    #print "xxx $gaps gaps vs $nogaps inner-paragraph lines\n";
    return max(0, min(1, 1.5 - $nogaps/$gaps));
    """

def confidence(doc):
    # low confidence suggests not the layout of an ordinary paper
    return doc.meta_confidence
classifier.likelihood('confidence', confidence, 
                      p_ifyes=nbinom(6, 0.1), p_ifno=nbinom(3, 0.1))

def evaluate(doc):
    debug(4, 'trying to guess if document is a paper')
    debugflag = debuglevel() > 3
    return classifier.test(doc, debug=debugflag, smooth=True)

if __name__ == '__main__':
    # graphical output for choosing distributions
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('condition', help='name of likelihood condition')
    args = ap.parse_args()

    for li in classifier.likelihoods:
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
