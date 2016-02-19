#!/usr/bin/env python3
import unittest
import re
import lxml.etree
import os.path
from docparser.pdf2xml import ocr2xml

curpath = os.path.abspath(os.path.dirname(__file__))
testdir = os.path.join(curpath, 'testdocs')

class PDFTest(object):
    """common setup and test methods for all pdfs"""

    xml = None
 
    def setUp(self):
        """call ocr2xml and read output into etree document self.xml"""
        if self.xml is not None:
            return True
        print('\n'+self.pdffile)
        xmlfile = self.pdffile.replace('.pdf', '.ocr.xml')
        ocr2xml.ocr2xml(self.pdffile, xmlfile, debug_level=0)
        with open(xmlfile, 'rb') as f:
            xml = f.read()
        self.__class__.xml = lxml.etree.fromstring(xml)
    
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
    
class A_SimplePDFTest(PDFTest, unittest.TestCase):

    pdffile = os.path.join(testdir, 'simple.pdf')

    def test_fontspecs(self):
        """testing number of fontspec elements"""
        self.assertEqual(self.num_fontspecs(), 4)
    
    def test_fontsizes(self):
        """testing font sizes"""
        fontsizes = [12,15,19,23]
        for i,fs in enumerate(self.fontsizes()):
            with self.subTest(i=i):
                self.assertAlmostEqual(fs, fontsizes[i], delta=1)

    def test_titleheight(self):
        """testing height of title text"""
        title = self.get_element('ipsum', page=1)
        height = int(title.xpath('@height')[0])
        self.assertAlmostEqual(height, 23, delta=3)

class B_CarnapPDFTest(PDFTest, unittest.TestCase):

    pdffile = os.path.join(testdir, 'carnap-short.pdf')

    def test_num_fontspecs(self):
        self.assertIn(self.num_fontspecs(), [4,5])
    
    def test_fontsizes(self):
        fontsizes = [9,10,12,14,15]
        for i,fs in enumerate(self.fontsizes()):
            with self.subTest(i=i):
                self.assertAlmostEqual(fs, fontsizes[i], delta=1)

    def test_uniform_content_font(self):
        page = self.get_page(1)
        fonts = page.xpath('./text/@font')
        for i in range(6,45):
            with self.subTest(i=i):
                self.assertEqual(fonts[i], fonts[i-1])

if __name__ == '__main__':
    unittest.main()
