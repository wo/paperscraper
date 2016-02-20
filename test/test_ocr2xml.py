#!/usr/bin/env python3
import pytest
import re
import lxml.etree
import os.path
from docparser import ocr2xml

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

class PDFTest():
    """common setup and test methods for all pdfs"""

    def __init__(self, pdffile):
        """call ocr2xml and read output into etree document self.xml"""
        xmlfile = pdffile.replace('.pdf', '.ocr.xml')
        ocr2xml.ocr2xml(pdffile, xmlfile, debug_level=0)
        with open(xmlfile, 'rb') as f:
            xml = f.read()
        self.xml = lxml.etree.fromstring(xml)
    
    def get_page(self, pagenum):
        """etree representation of page"""
        page = self.xml.xpath('//page[@number="{}"]'.format(pagenum))[0]
        return page
    
    def get_element(self, textfragment, page=1):
        """element on page that containts textfragment"""
        page = self.get_page(page)
        els = page.xpath(".//*[contains(text(),'{}')]".format(textfragment))
        return els[0] if els else None

    def num_fontspecs(self, page=1):
        """number of fontspec elements on page"""
        page = self.get_page(page)
        fontspecs = page.xpath('./fontspec')
        return len(fontspecs)
    
    def fontsizes(self, page=1):
        """fontsizes of fontspec elements on page, in order of size"""
        page = self.get_page(page)
        fontsizes = page.xpath('./fontspec/@size')
        return sorted([int(fs) for fs in fontsizes])


@pytest.fixture(scope="module")
def simplepdf():
    pdffile = os.path.join(testdir, 'simple.pdf')
    return PDFTest(pdffile)

def test_simple_num_fontspecs(simplepdf, caplog):
    """testing number of fontspec elements"""
    assert simplepdf.num_fontspecs() == 4

def test_simple_fontsizes(simplepdf, caplog):
    """testing font sizes"""
    fontsizes = [12,15,19,23]
    for i,fs in enumerate(simplepdf.fontsizes()):
        assert fontsizes[i]-1 <= fs <= fontsizes[i]+1

def test_simple_titleheight(simplepdf, caplog):
    """testing height of title text"""
    title = simplepdf.get_element('ipsum', page=1)
    height = int(title.xpath('@height')[0])
    assert 20 <= height <= 26


@pytest.fixture(scope="module")
def carnappdf():
    pdffile = os.path.join(testdir, 'carnap-short.pdf')
    return PDFTest(pdffile)

def test_carnap_num_fontspecs(carnappdf, caplog):
    """testing number of fontspec elements"""
    assert 4 <= carnappdf.num_fontspecs() <= 5

def test_carnap_fontsizes(carnappdf, caplog):
    """testing font sizes"""
    fontsizes = [9,10,12,14,15]
    for i,fs in enumerate(carnappdf.fontsizes()):
        assert fontsizes[i]-1 <= fs <= fontsizes[i]+1
        
def test_carnap_uniformfont(carnappdf, caplog):
    """testing uniform content font"""
    page = carnappdf.get_page(1)
    fonts = page.xpath('./text/@font')
    for i in range(6,45):
        assert fonts[i] == fonts[i-1]

#pdffile = os.path.join(testdir, 'fleurbaeymonginSCW05.pdf')

if __name__ == '__main__':
    unittest.main()
