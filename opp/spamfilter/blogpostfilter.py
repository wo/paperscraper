from os.path import isfile, abspath, dirname, join
import logging
import re
import pickle
from numpy import array
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics import accuracy_score
from sklearn.metrics import classification_report
from sklearn.metrics import confusion_matrix
from sklearn.naive_bayes import MultinomialNB

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class BinaryClassifier:
    
    def __init__(self, label):
        logger.debug("initializing {0} classifier".format(label))
        self.label = label
        self.picklefile = join(abspath(dirname(__file__)), 'jsonserver/data/{0}.pk'.format(label))
        self.vectorizer = None
        self.classifier = None
        self.ready = False

    def load(self):
        if isfile(self.picklefile):
            logger.debug("loading classifier model from disk")
            with open(self.picklefile, 'rb') as f:
                (vect,clf) = pickle.load(f)
            self.vectorizer = vect
            self.classifier = clf
            self.ready = True
        else:
            self.reset()
    
    def reset(self):
        logger.debug("creating new classifier")
        self.vectorizer = TfidfVectorizer(strip_accents='ascii',
                                          stop_words='english')
        self.classifier = MultinomialNB(alpha=0.01)
        self.ready = False
            
    def save(self):
        logger.debug("saving classifier model to disk")
        with open(self.picklefile,'wb') as f:
            pickle.dump((self.vectorizer, self.classifier), f)

    def train(self, docs, hamspam):
        self.reset()
        # Tokenize the texts:
        texts = [doc.text for doc in docs]
        tfidfs = self.vectorizer.fit_transform(texts)
        logger.debug('Dimensions of tfidfs are', tfidfs.shape)
        #logger.debug(self.vectorizer.get_feature_names())
        hamspam = array(hamspam).ravel()
        self.classifier = MultinomialNB().fit(tfidfs, hamspam)
        self.ready = True

    def classify(self, docs):
        if self.classifier is None:
            self.load()
        if not self.ready:
            logger.warn("classifier not ready, returning dummy values 0.5")
            return [(0.5,0.5) for doc in docs]
        texts = [doc.text for doc in docs]
        tfidfs = self.vectorizer.transform(texts)
        probs = self.classifier.predict_proba(tfidfs)
        return probs

class Doc:
    
    def __init__(self, hash):

        if len(hash['content']) < 100000:
            self.text = hash['content']
        else:
            self.text = hash['content'][:50000] + hash['content'][-50000:]
        
        # Simple hack to add authors etc. to document features:
        self.text += (" " + hash['title']) * 2
        for au in hash['authors'].split(","):
            self.text += " " + re.sub(r' (\w+)\s*', r' XAU_\1', au)
        m = re.match(r'(.+)/[^/]*', hash['url']) # url path
        if (m):
            self.text += " XPATH_" + re.sub(r'\W', '_', m.group(1))
        self.text += " XTYPE_" + hash['filetype']
        
        #logger.debug(self.text)

import re


doc = { 'title':'foo' }
blogspamfilter.test(doc)

