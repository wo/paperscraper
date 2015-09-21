import logging
import math
import re

logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

class BinaryNaiveBayes:

    def __init__(self, prior_yes):
        self.prior = prior_yes
        self.likelihoods = []

    def likelihood(self, description, condition, p_yes, p_no):
        # stay regular, avoid infinite logs:
        if p_yes == 0:
            p_yes = 0.0000001
        if p_no == 0:
            p_no = 0.0000001
        self.likelihoods.append((description, condition, p_yes, p_no))

    def test(self, target):
        # p(Yes/F1&F2) = p(F1&F2/Yes) p(Yes)/p(F1&F2)
        #               = p(F1/Yes)p(F2/Yes) p(Yes)/p(F1&F2)   [Naive Independence]
        #               = e**(logp(F1/Yes)+logp(F2/Yes)+logp(Yes)-logp(F1&F2))
        logp_yes = math.log(self.prior)
        logp_no = math.log(1-self.prior)
        logger.debug("prior yes {}, no {}".format(math.e**logp_yes, math.e**logp_no))
        for li in self.likelihoods:
            if li[1](target):
                logger.debug("{}? yes".format(li[0]))
                logp_yes += math.log(li[2])
                logp_no += math.log(li[3])
            else:
                logger.debug("{}? no".format(li[0]))
                # if p(F/Yes) = x then p(~F/Yes) = 1-x
                logp_yes += math.log(1-li[2])
                logp_no += math.log(1-li[3])
        # p(F1&F2) = p(F1&F2/Yes)p(Yes) + p(F1&F2/No)p(No)
        logp_features = math.log(math.e**logp_yes + math.e**logp_no)
        logger.debug("prior probability of features: {}".format(math.e**logp_features))
        logp_yes -= logp_features
        logp_no -= logp_features
        logger.debug("result: p_yes {}".format(math.e**logp_yes))
        return math.e**logp_yes

        
'''

blogyesfilter = BinaryNaiveBayes(prior=0.4)

blogyesfilter.likelihood(
    lambda post: re.search(r'call for papers|\bcfp\b', post['title']) is not None,
    yes=0.3, no=0.01)


doc = { 'title':'foo' }
blogyesfilter.test(doc)

'''
