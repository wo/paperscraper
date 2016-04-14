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
from debug import debug
from exceptions import UntrainedClassifierException

class DocClassifier:
    """
    A binary Doc classifier based on scikit-learn, used to distinguish
    documents by their content.
    
    mc = DocClassifier('/tmp/metaphysics.pk')
    mc.load()
    mc.train([doc1,doc2,doc3], [True, True, False])
    mc.save()
    ...
    mc.classify([doc4,doc5,doc6])
    """
    
    def __init__(self, picklefile):
        debug(4, "initializing classifier %s", picklefile)
        self.picklefile = picklefile
        self.vectorizer = None
        self.classifier = None
        self.ready = False

    def load(self):
        if isfile(self.picklefile):
            debug(4, "loading classifier model from disk")
            with open(self.picklefile, 'rb') as f:
                (vect,clf) = pickle.load(f)
            self.vectorizer = vect
            self.classifier = clf
            self.ready = True
        else:
            self.reset()
    
    def reset(self):
        debug(4, "resetting classifier")
        self.vectorizer = TfidfVectorizer(strip_accents='ascii',
                                          stop_words='english')
        self.classifier = MultinomialNB(alpha=0.01)
        self.ready = False
            
    def save(self):
        debug(4, "saving classifier model to disk")
        with open(self.picklefile, 'wb') as f:
            pickle.dump((self.vectorizer, self.classifier), f)

    def train(self, docs, hamspam):
        """
        trains filter with list of docs and correponding list of Boolean
        values
        """
        self.reset()
        texts = [self.doc2text(doc) for doc in docs]
        # Tokenize the texts:
        tfidfs = self.vectorizer.fit_transform(texts)
        debug(4, 'Dimensions of tfidfs are %s', tfidfs.shape)
        debug(5, self.vectorizer.get_feature_names())
        hamspam = array(hamspam).ravel()
        self.classifier.fit(tfidfs, hamspam)
        debug(5, 'classes: %s', self.classifier.classes_)
        self.ready = True

    def classify(self, docs):
        """
        takes list of Doc objects and returns list of probabilities;
        raises Exception if classifier isn't trained.
        """
        if self.classifier is None:
            self.load()
        if not self.ready:
            raise UntrainedClassifierException("classifier is not trained")
        texts = [self.doc2text(doc) for doc in docs]
        tfidfs = self.vectorizer.transform(texts)
        probs = self.classifier.predict_proba(tfidfs)
        yes_index = 0 if self.classifier.classes_[0] else 1
        return [p[yes_index] for p in probs]

    @staticmethod
    def doc2text(doc):
        if len(doc.content) < 100000:
            text = doc.content
        else:
            text = doc.content[:50000] + doc.content[-50000:]
        # Simple hack to add authors etc. to document features:
        if len(text):
            if len(text) < 4000:
                text += " XLEN_TINY" * 2
            elif len(text) < 8000:
                text += " XLEN_VSHORT" * 2
            elif len(text) < 15000:
                text += " XLEN_SHORT" * 2
            elif len(text) < 40000:
                text += " XLEN_MEDIUM" * 2
            elif len(text) < 80000:
                text += " XLEN_LONG" * 2
            else:
                text += " XLEN_VLONG {}" * 2
        if doc.title:
            text += (" " + doc.title) * 2
        if doc.authors:
            for au in doc.authors.split(","):
                text += " " + re.sub(r' (\w+)\s*', r' XAU_\1', au)
        m = doc.url and re.match(r'(.+)/[^/]*', doc.url) # url path
        if m:
            text += " XPATH_" + re.sub(r'\W', '_', m.group(1))
        if doc.filetype:
            text += " XTYPE_" + doc.filetype

        debug(5, "doc text for classification:\n%s\n", text)
        return text

