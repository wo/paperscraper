#!/usr/bin/env python3
import pytest
from subjectivebayes import BinaryNaiveBayes
from scipy.stats import binom

def test_basic():
    nb = BinaryNaiveBayes(prior_yes=0.5)
    nb.likelihood('', lambda x: True, p_ifyes=0.3, p_ifno=0.1)
    # 0.3 * 0.5 / 0.3 * 0.5 + 0.1 * 0.5 = 0.75
    assert 0.749 < nb.test(0) < 0.751

def test_medical():
    nb = BinaryNaiveBayes(prior_yes=0.0001)
    nb.likelihood('', lambda x: True, p_ifyes=0.99, p_ifno=0.01)
    assert 0.0097 < nb.test(0) < 0.0099

#def test_zscore():
#    nb = BinaryNaiveBayes(prior_yes=0.2)
#    nb.likelihood('', lambda x: x, p_ifyes=binom(10,5), p_ifno=binom(20,10))
#    assert 0.44 < nb.test(10, debug=True) < 0.45
#    assert 0.11 < nb.test(15, debug=True) < 0.12

