import logging
import numbers
import math
import re

logger = logging.getLogger('opp')

class BinaryNaiveBayes:
    """
    A "subjective" naive Bayesian classifier; i.e. the likelihoods are
    not trained from data, but set by hand.

    Exampe usage:
    
    from scipy.stats import nbinom
    spamfilter = BinaryNaiveBayes(prior_yes=0.4)
    spamfilter.likelihood("contains 'viagra'", lambda s: 'viagra' in s,
                          p_ifyes=0.5, p_ifno=0.001)
    spamfilter.likelihood("length", lambda s: len(s),
                          p_ifyes=nbinom(1,0.1), p_ifno=nbinom(2,0.01))
    spamfilter.test('Buy viagra now')

    There are two ways of specifying likelihoods, depending on whether
    the relevant feature is binary or numerical. 

    For binary features, the second (condition) argument to
    self.likelihood is a function that takes the object to test and
    returns True or False; the p_ifyes and p_ifno arguments specify
    the probability of True given a 'yes' and 'no' case, respectively.

    For numerical features, the condition argument is a function that
    takes the object to test and returns a number; p_ifyes then
    specifies a discrete scipy.stats probability distribution given a
    'yes' case, p_ifno for 'no' cases.
    """

    def __init__(self, prior_yes):
        self.prior = prior_yes
        self.likelihoods = []

    def likelihood(self, description, condition, p_ifyes, p_ifno):
        # stay regular, avoid infinite logs:
        if p_ifyes == 0:
            p_ifyes = 0.0000001
        if p_ifyes == 1:
            p_ifyes = 0.9999999
        if p_ifno == 0:
            p_ifno = 0.0000001
        if p_ifno == 1:
            p_ifno = 0.9999999
        self.likelihoods.append((description, condition, p_ifyes, p_ifno))

    def test(self, target, debug=False, smooth=False):
        """
        p(Yes/F1&F2) = p(F1&F2&Yes)/p(F1&F2)
                      = p(F1/Yes)p(F2/Yes)p(Yes)/p(F1&F2)   [Naive Independence]
                      = e^[logp(F1/Yes)+logp(F2/Yes)+logp(Yes)-logp(F1&F2)]
        
        Let logpos = logp(Yes) + logp(F1/Yes) + logp(F2/Yes) + ...
        Let logfeat = logp(F1&F2&...)
        
        So p(Yes/F1&F2..) = e^[logpos - logfeat].

        What is logfeat? Well, p(F1&F2..) = p(F1&F2..&Yes) + p(F1&F2..&No).
        So logfeat = log[p(F1&F2..)] = log[e^logpos + e^logneg],
        where logneg = logp(No&F1&F2..)
                     = logp(No) + logp(F1/No) + logp(F2/No) + ...
        """
        logpos = math.log(self.prior) # initialize logp(Yes)
        logneg = math.log(1-self.prior) # initialize logp(No)
        if debug:
            print("prior {}".format(self.prior))
        for li in self.likelihoods:
            (description, condition, p_ifyes, p_ifno) = li
            res = condition(target)
            if debug:
                print ("{}? {}".format(description, res))
            if res == Ellipsis:
                # skip features that don't apply
                continue
            if isinstance(p_ifyes, numbers.Number):
                # p(~F/Yes) = 1-P(F/Yes)
                pos = p_ifyes if res else 1-p_ifyes
                neg = p_ifno if res else 1-p_ifno
            else:
                pos = max(p_ifyes.pmf(res), 1.e-10)
                neg = max(p_ifno.pmf(res), 1.e-10)
                if smooth:
                    if pos > neg:
                        neg = max((neg+pos)/2, pos/10)
                    elif neg > pos:
                        pos = max((neg+pos)/2, neg/10)
            if debug:
                print("likelihood {} if yes, {} if no".format(pos, neg))
            logpos += math.log(pos)
            logneg += math.log(neg)
        logfeat = math.log(math.exp(logpos) + math.exp(logneg))
        if debug:
            print("prior probability of features: {}".format(math.exp(logfeat)))
        logp_yes = logpos - logfeat
        p_yes = math.exp(logp_yes)
        if debug:
            print("result: p_yes {}".format(p_yes))
        return p_yes
                              
class SubjectiveNaiveBayes:
    """
    A "subjective" naive Bayesian classifier; i.e. the likelihoods are
    not trained from data, but set by hand.

    Exampe usage:
    
    spamfilter = SubjectiveNaiveBayes(prior_yes=0.4)
    spamfilter.likelihood("contains 'viagra'", 
                          lambda s: 'viagra' in s,
                          p_ifyes=0.5, p_ifno=0.001)
    spamfilter.likelihood("attachement is large (ignored if no attachment)", 
                          lambda s: len(s.attachment) > 1000,
                          precondition=lambda s:(s.attachment is not None),
                          p_ifyes=0.5, p_ifno=0.001)
    spamfilter.likelihood("length", 
                          lambda s: len(s),
                          p=(
                             (10, .1, .2), # 0-10: probability .1 if yes, .2 if no
                             (200, .3, .5), # 0-200: probability .3 if yes, .5 if no
                             (800, .8, .9), # 0-800: probability .8 if yes, .9 if no
                          ))
    spamfilter.test('Buy viagra now')

    There are two ways of specifying likelihoods, depending on whether
    the relevant feature is binary or numerical. 

    For binary features, the second (condition) argument to
    self.likelihood is a function that takes the object to test and
    returns True or False; the p_ifyes and p_ifno arguments specify
    the probability of True given a 'yes' and 'no' case, respectively.

    For numerical features, the condition argument is a function that
    takes the object to test and returns a number; p then
    specifies chunked cumulative probabilitys distribution given a
    'yes' and 'no' case.
    """

    def __init__(self, prior_yes):
        self.prior = prior_yes
        self.likelihoods = []

    def likelihood(self, description, condition, p_ifyes=None, p_ifno=None, p=None, precondition=None):
        # stay regular, avoid infinite logs:
        if p_ifyes == 0:
            p_ifyes = 0.0000001
        if p_ifyes == 1:
            p_ifyes = 0.9999999
        if p_ifno == 0:
            p_ifno = 0.0000001
        if p_ifno == 1:
            p_ifno = 0.9999999
        if p:
            (p_ifyes, p_ifno) = self.pdist(p)
        self.likelihoods.append((description, condition, precondition, p_ifyes, p_ifno))

    @staticmethod
    def pdist(p):
        # turn cumulative p into chunked probability distributions:
        def dist(yes, n):
            prev_pr = 0
            for (threshold, pr_y, pr_n) in p:
                pr = pr_y if yes else pr_n
                if n <= threshold:
                    return pr - prev_pr
                prev_pr = pr
            return 1 - prev_pr
        return (lambda n: dist(True, n), lambda n: dist(False, n))
    
    def test(self, target, debug=False):
        """
        p(Yes/F1&F2) = p(F1&F2&Yes)/p(F1&F2)
                      = p(F1/Yes)p(F2/Yes)p(Yes)/p(F1&F2)   [Naive Independence]
                      = e^[logp(F1/Yes)+logp(F2/Yes)+logp(Yes)-logp(F1&F2)]
        
        Let logpos = logp(Yes) + logp(F1/Yes) + logp(F2/Yes) + ...
        Let logfeat = logp(F1&F2&...)
        
        So p(Yes/F1&F2..) = e^[logpos - logfeat].

        What is logfeat? Well, p(F1&F2..) = p(F1&F2..&Yes) + p(F1&F2..&No).
        So logfeat = log[p(F1&F2..)] = log[e^logpos + e^logneg],
        where logneg = logp(No&F1&F2..)
                     = logp(No) + logp(F1/No) + logp(F2/No) + ...
        """
        logpos = math.log(self.prior) # initialize logp(Yes)
        logneg = math.log(1-self.prior) # initialize logp(No)
        if debug:
            print("prior {}".format(self.prior))
        for li in self.likelihoods:
            (description, condition, precondition, p_ifyes, p_ifno) = li
            if precondition and not precondition(target):
                continue
            res = condition(target)
            if debug:
                print ("{}? {}".format(description, res))
            if isinstance(p_ifyes, numbers.Number):
                # p(~F/Yes) = 1-P(F/Yes)
                pos = p_ifyes if res else 1-p_ifyes
                neg = p_ifno if res else 1-p_ifno
            else:
                pos = p_ifyes(res)
                neg = p_ifno(res)
            if debug:
                print("likelihood {} if yes, {} if no".format(pos, neg))
            logpos += math.log(pos)
            logneg += math.log(neg)
        logfeat = math.log(math.exp(logpos) + math.exp(logneg))
        if debug:
            print("prior probability of features: {}".format(math.exp(logfeat)))
        logp_yes = logpos - logfeat
        p_yes = math.exp(logp_yes)
        if debug:
            print("result: p_yes {}".format(p_yes))
        return p_yes
                              
