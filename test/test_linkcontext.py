#!/usr/bin/env python3
import pytest
import logging
import os.path
import sys
from opp.models import Link
from opp.browser import Browser
from opp.debug import debuglevel

VDISPLAY = True

@pytest.mark.parametrize("page,link,context", [

    ('umsu.html',
     'http://www.umsu.de/papers/functionalism.pdf',
     '''\
Analytic Functionalism
In Barry Loewer and Jonathan Schaffer (eds.), A Companion to David Lewis, Malden, MA: Wiley-Blackwell, 2015: 504-518'''),
    
    ('paolosantorio.html',
     'http://paolosantorio.net/ssw.ac.pdf',
     '''\
Selection Function Semantics for Will, with Fabrizio Cariani
Forthcoming in Proceedings of the Amsterdam Colloquium
(abstract | final version)'''),

    ('ajjulius.html',
     'http://www.ajjulius.net/papers/poe.pdf',
     'The possibility of exchange, Politics, philosophy, and economics, 12: 4, 2013'),

    ('ajjulius.html',
     'http://www.ajjulius.net/papers/julius_kadish.pdf',
     'A lonelier contractualism'),

    ('ajjulius.html',
     'http://www.ajjulius.net/reconstruction.pdf',
     'book ms, 12/7/13 draft\nReconstruction'),

    ('philpapers.html',
     'http://philpapers.org/rec/SAAOTC',
     '''\
Acta Analytica
forthcoming articles
Amit Saad, On the Coherence of Wittgensteinian Constructivism.No categories Direct download (2 more)     Export citation     My bibliography'''),

    ('philpapers.html',
     'http://philpapers.org/go.pl?id=SAAOTC&proxyId=&u=http%3A%2F%2Fdx.doi.org%2F10.1007%2Fs12136-016-0284-1',
     '''\
Amit Saad, On the Coherence of Wittgensteinian Constructivism.
No categories Direct download (2 more)     Export citation     My bibliography'''),

    ('philpapers.html',
     'http://philpapers.org/rec/ANTTEO-8',
     '''\
Kyriakos Antoniou, Kleanthes K. Grohmann, Maria Kambanaros & Napoleon Katsos, The Effect of Childhood Bilectalism and Multilingualism on Executive Control.
Cognitive Sciences  Direct download (2 more)     Export citation     My bibliography'''),

    ('researchgate.html',
     'https://www.researchgate.net/profile/J_Velleman/publication/259425635_Dying/links/0046352c3434bad606000000.pdf?origin=publication_list',
     '''\
Article:     Dying
J. David Velleman
Full-text   · Article · Sep 2012  · Think
Download'''),
    
    ('consc.html',
     'http://consc.net/papers/revisability.pdf',
     'Revisability and Conceptual Change in "Two Dogmas of Empiricism".  Journal of Philosophy 108:387-415, 2011.'),

#    ('searle.html',
#     'http://socrates.berkeley.edu/~jsearle/BiologicalNaturalismOct04.doc',
#     '"Biological Naturalism" Word document'),

#    ('cath-broken.html',
#     'http://philrsss.anu.edu.au/people-defaults/yuricath/function.require',
#     'Warning: require() [function.require]: URL file-access is disabled in the server configuration in /var/www/philosophy/public_html/people-defaults/yuricath/index.php3 on line 1'),
     
# The following test isn't very meaningful because the source page
# contains insane <span>s that cut across entries.
#
#    ('mongin.html',
#     'https://studies2.hec.fr/jahia/webdav/site/hec/shared/sites/mongin/acces_anonyme/page%20internet/O12.MonginExpectedHbk97.pdf',
#     '(O12) "Expected Utility Theory " , Handbook of Economic Methodology, J. Davis, W. Hands and U. Mäk (eds), London, Elgar, 1997, p. 342-350.'),
    
])
def test_linkcontext(page, link, context, caplog):
    caplog.set_level(logging.CRITICAL, logger='selenium')
    caplog.set_level(logging.DEBUG, logger='opp')
    debuglevel(5)
    curpath = os.path.abspath(os.path.dirname(__file__))
    testdir = os.path.join(curpath, 'sourcepages')
    browser = Browser()
    src = 'file://'+testdir+'/'+page
    browser.goto(src)
    el = browser.find_elements('xpath', '//a[@href="{}"]'.format(link))[0]
    li = Link(element=el)
    res = li.html_context()
    assert res == context
