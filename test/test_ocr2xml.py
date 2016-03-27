#!/usr/bin/env python3
import pytest
import logging
import re
import lxml.etree
import lxml.html
import os.path
from debug import debuglevel
from pdftools import ocr2xml

debuglevel(4)

def test_tidy_hocr_line(caplog):
    html = ("<html><body><text>"
            "<span class='ocrx_word' id='word_1_1' title='bbox 465 463 520 485; x_wconf 72' lang='eng' dir='ltr'><strong>Ene</strong></span> "
            "<span class='ocrx_word' id='word_1_2' title='bbox 532 463 645 485; x_wconf 74' lang='eng' dir='ltr'><strong><em>mene</em></strong></span> "
            "<span class='ocrx_word' id='word_1_3' title='bbox 662 469 691 484; x_wconf 75' lang='eng' dir='ltr'>mu</span>"
            "</text></body></html>")
    hocr = lxml.html.document_fromstring(html)
    line = hocr.xpath('//text')[0]
    nline = ocr2xml.tidy_hocr_line(line)
    linehtml = lxml.etree.tostring(nline, encoding=str)
    assert linehtml == '<text><b>Ene <i>mene</i> mu</b></text>'

def test_tidy_hocr_line2(caplog):
    html = ("<html><body><text>"
            "<span class='ocrx_word' id='word_1_1' title='bbox 465 463 520 485; x_wconf 72' lang='eng' dir='ltr'><strong>Ene</strong></span> "
            "<span class='ocrx_word' id='word_1_2' title='bbox 532 463 645 485; x_wconf 74' lang='eng' dir='ltr'><strong>mene <em>miste</em> es</strong> rappelt</span> "
            "<span class='ocrx_word' id='word_1_3' title='bbox 662 469 691 484; x_wconf 75' lang='eng' dir='ltr'>in der Kiste</span>"
            "</text></body></html>")
    hocr = lxml.html.document_fromstring(html)
    line = hocr.xpath('//text')[0]
    nline = ocr2xml.tidy_hocr_line(line)
    linehtml = lxml.etree.tostring(nline, encoding=str)
    assert linehtml == '<text><b>Ene mene <i>miste</i> es</b> rappelt in der Kiste</text>'

def test_tidy_hocr_line3(caplog):
    # just cheking that empty lines are handled gracefully
    html = ("<html><body><text></text></body></html")
    hocr = lxml.html.document_fromstring(html)
    line = hocr.xpath('//text')[0]
    ocr2xml.tidy_hocr_line(line)
    assert True


curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

class PDFTest():
    """common setup and test methods for all pdfs"""

    def __init__(self, pdffile):
        """call ocr2xml and read output into etree document self.xml"""
        xmlfile = pdffile.replace('.pdf', '.ocr.xml')
        ocr2xml.ocr2xml(pdffile, xmlfile, keep_tempfiles=True)
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
        
@pytest.fixture(scope="module")
def monginpdf():
    pdffile = os.path.join(testdir, 'fleurbaeymonginSCW05.pdf')
    return PDFTest(pdffile)

def test_mongin_title(caplog):
    pdffile = os.path.join(testdir, 'fleurbaeymonginSCW05.pdf')
    monginpdf = PDFTest(pdffile)
    assert monginpdf.get_element('greatly exaggerated', page=1) is not None

if __name__ == '__main__':
    unittest.main()


