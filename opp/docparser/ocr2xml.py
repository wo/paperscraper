#!/usr/bin/env python3
import logging
import re
import os
from os.path import join, basename
import sys
import tempfile
import shutil
import subprocess
from collections import defaultdict
from statistics import median, stdev
import lxml.html
import lxml.etree
from timeit import default_timer as timer
from .exceptions import *
from .pdfinfo import pdfinfo

OCR_DPI = 300

logger = logging.getLogger('opp')

def debug(level, msg, *args):
    if debug.debug_level >= level:
        logger.debug(msg, *args)
debug.debug_level = 0

def tempdir():
    if not hasattr(tempdir, 'dirname'):
        tempdir.dirname = tempfile.mkdtemp()
        debug(2, "creating temporary directory: %s", tempdir.dirname)
    return tempdir.dirname

def remove_tempdir():
    shutil.rmtree(tempdir())
    del tempdir.dirname

def ocr2xml(pdffile, xmlfile, debug_level=0, keep_tempfiles=False, write_hocr=False):
    """ocr pdffile and write pdftohtml-type parsing to xmlfile"""

    debug.debug_level = debug_level
    start_time = timer()
    debug(2, "ocr2xml %s %s", pdffile, xmlfile)

    try:
        numpages = int(pdfinfo(pdffile)['Pages'])
    except e:
        raise MalformedPDFError('pdfinfo failed')
    debug(1, '%s pages to process', numpages)
    
    xml = init_xml()
    hocr = b''
    for p in range(numpages):
        page_hocr = ocr_page(pdffile, p+1)
        xml_add_page(xml, page_hocr)
        hocr += page_hocr

    xmlstr = lxml.etree.tostring(xml, encoding='utf-8', pretty_print=True,
                                 xml_declaration=True)
    with open(xmlfile, 'wb') as f:
        f.write(hocr if write_hocr else xmlstr)

    end_time = timer()
    if not keep_tempfiles:
        debug(3, 'cleaning up')
        remove_tempdir()

    debug(1, 'Time: %s seconds', str(end_time - start_time))

def ocr_page(pdffile, pagenum):
    """ return (binary) hocr output for single page """
    tempbase = join(tempdir(), basename(pdffile)+'.'+str(pagenum))
    
    debug(2, 'extracting page %s', pagenum) 
    pagepdf = tempbase+'.pdf'
    cmd = ['pdftk', pdffile, 'cat', str(pagenum), 'output', pagepdf]
    debug(3, ' '.join(cmd))
    subprocess.check_call(cmd, timeout=2)
    
    debug(2, 'converting page to image') 
    pageppm = tempbase+'.ppm'
    cmd = ['pdftoppm', '-r', str(OCR_DPI), pagepdf]
    debug(3, '%s > %s', ' '.join(cmd), pageppm)
    with open(pageppm, 'wb') as f:
        subprocess.check_call(cmd, stdout=f, timeout=2)
    
    debug(2, 'ocr-ing image') 
    cmd = ['tesseract', pageppm, 'stdout', '-l', 'eng', 'hocr']
    debug(3, ' '.join(cmd))
    output = subprocess.check_output(cmd, timeout=20)
    return output

def init_xml():
    root = lxml.etree.Element("pdf2xml");
    xml_add_page.page_count = 0
    return root

def xml_add_page(xml, page_hocr):
    """
    pdftohtml pages look like this:
    
    <page number="1" position="absolute" top="0" left="0" height="1262" width="892">
	<fontspec id="0" size="23" family="Times" color="#000000"/>
        ....
    <text top="247" left="314" width="288" height="23" font="0">Lorem ipsum</text>
    ...
    </page>
    
    hOCR doesn't give information about font family, so I pretend
    everything is "Times", and I try to guess the font size from the
    character bboxes.
    """
    
    debug(2, 'converting hocr to pdtohtml-style xml')
    
    xml_add_page.page_count += 1
    re_bbox = re.compile('bbox (\d+) (\d+) (\d+) (\d+)')
    
    hocr = lxml.html.document_fromstring(page_hocr)
    try:
        hocr_page = hocr.xpath('//div[@class="ocr_page"]')[0]
    except IndexError:
        logger.debug("no ocr_page element in hocr output!")
        return xml
    m = re_bbox.search(hocr_page.xpath('@title')[0])
    (page_width, page_height) = (m.group(3), m.group(4)) if m else (0,0)
    xml_page = lxml.etree.SubElement(xml, 'page', 
                                     number=str(xml_add_page.page_count),
                                     width=str(round(scale(page_width))),
                                     height=str(round(scale(page_height))))

    fontsizes = [] # fontsize for each line
    fontnumbers = [] # number => size
    texts = []
    for line in hocr_page.xpath('//span[@class="ocr_line"]'):
        # convert line to pdftohtml text element:
        debug(5, 'hocr line:%s', lxml.etree.tostring(line, encoding='utf-8'))
        attribs = line_attribs(line)
        if not attribs['height']:
            debug(2, "ignoring line without height!")
            continue
        line.tag = 'text'
        line.attrib.clear()
        line.set('left', str(attribs['left']))
        line.set('top', str(attribs['top']))
        line.set('width', str(attribs['width']))
        line.set('height', str(attribs['height']))
        fontsize = attribs['fontsize']
        if fontsizes and round(fontsize) != fontsizes[-1]:
            if abs(fontsize - fontsizes[-1]) < attribs['fontsize_plusminus']:
                fontsize = fontsizes[-1]
                debug(4, "adjusting font size to previous line: %s", fontsize)
        fontsize = round(fontsize)
        fontsizes.append(fontsize)
        if fontsize not in fontnumbers:
            fontnumbers.append(fontsize)
        line.set('font', str(fontnumbers.index(fontsize)))
        line = tidy_hocr_line(line)
        texts.append(line)
    xml_page.text='\n   '
    for i,fs in enumerate(fontnumbers):
        fsp = lxml.etree.Element('fontspec', id=str(i), size=str(fs), family='Times', color='#000')
        xml_page.append(fsp)
        fsp.tail='\n   '
    for text in texts:
        xml_page.append(text)

def tidy_hocr_line(line):
    """
    remove hocr markup for individual words, replace <strong> by <b>,
    <em> by <i>, merge consecutive elements etc.
    """
    # remove individual word/node hocr markup; don't discard all
    # markup to preserve <strong> etc.:
    lxml.etree.strip_tags(line, 'span')
    # The following operations are much easier on trings than on etree
    # xml trees.
    linestr = lxml.etree.tostring(line, encoding=str).rstrip()
    m = re.match('(<text.*?>)(.*)(</text>)', linestr)
    if not m:
        return line
    (start, content, end) = m.groups()
    content = content.replace('strong>', 'b>')
    content = content.replace('em>', 'i>')
    # merge consecutive:
    content = re.sub('</b>(.{0,4})<b>', r'\1', content)
    content = re.sub('</i>(.{0,4})<i>', r'\1', content)
    # if most of a line is bold, make whole line bold (important for
    # title extraction):
    debug(1, content)
    bpart = ''.join(re.findall('<b>.+?</b>', content))
    debug(1, bpart)
    if len(bpart) > len(content)*2/3:
        debug(1, '%s > %s', len(bpart), len(content)*2/3)
        content = '<b>'+re.sub('</?b>', '', content)+'</b>'
    debug(1, content)
    linestr = start + content + end
    debug(1, linestr)
    return lxml.etree.fromstring(linestr)

def scale(x):
    # A4 documents are 210 x 297 mm = 8.27 x 11.69 in = approx 595
    # x 842 pt (72 points = 1 inch). pdftohtml automatically
    # "zooms" in by 1.5, so we get page dimensions of 892 x
    # 1262. When we convert an A4 pdf to an image at 300 DPI/PPI,
    # we get (8.27 * 300 = 2481) x (11.69 * 300) = 3507 px. These
    # are the pixel units we find in the hocr output. To convert
    # them into pdftohtml units, we have to divide by 300 (giving
    # us inches), then multiply by 72 (giving points), then
    # multiply by 1.5 (giving zoomed-in points).
    return int(x) / OCR_DPI * 72 * 1.5

def line_attribs(line):
    """
    returns dict with keys left, top, width, height, fontsize,
    fontsize_plusminus (the latter determining a credible interval
    around fontsize, which reflects how well the font size could be
    estimated)
    """
    re_bbox = re.compile('bbox (\d+) (\d+) (\d+) (\d+)')
    m = re_bbox.search(line.xpath('@title')[0])
    if not m:
        return defaultdict(int)
    (left, top, right, bottom) = map(scale, m.groups())
    # tesseract lines have title attributes like this: "bbox 579 2640
    # 1427 2673; baseline -0.001 -6"; the second baseline number seems
    # to indicate the amount by which the font descends below its
    # baseline (here: 6).
    #re_descent = re.compile('baseline [-\d\.]+ ([\d\-]+)')
    #m = re_descent.search(line.xpath('@title')[0])
    #descent = int(m.group(1))*-1 if m else 0
    #debug(5, 'left: %s, top: %s, width: %s, height: %s, descent: %s',
    #      str(left), str(top), str(right-left), str(bottom-top), str(descent))

    # In scanned documents, words are often not horizontally aligned,
    # so that the difference between the top and bottom of a line
    # element does not adequately capture the true line height. That's
    # one reason to go through all words on the line. The other is to
    # determine the font size (= the scaled height of a word
    # containing capital letter and letters descending below the
    # baseline).
    height = 0
    # distinguish fontsize guesses of different credibility:
    fontsize_guesses = { 'good': [], 'bad': [], 'terrible': [] } 
    for word in line.xpath('./span[@class="ocrx_word"]'):
        m = re_bbox.search(word.xpath('@title')[0])
        (wleft, wtop, wright, wbottom) = map(scale, m.groups())
        wtext = word.xpath('string()')
        wheight = wbottom - wtop
        debug(5, "  '%s': height %s", wtext, str(wheight))
        # pdfhtml text 'height' is insensitive to whether a text has
        # letters like 'qyp' extending below the baseline -- it always
        # computes a height including such letters. So if a word
        # doesn't have sufficiently descending letters, we have to add
        # a bit to (wbottom-wtop)
        has_desc = re.search('[qypgj;,]', wtext)
        if not has_desc:
            wheight = wheight * 1.3
            debug(5, '    height adjusted to %s', str(wheight))
        #height_to_base = scale(bottom + baseline - top)
        #height = scale(bottom-top) if baseline < -1 else int(height_to_base * 1.3)
        height = max(height, wheight)
        # Now estimate font size:
        has_caps = re.search('[A-Z]', wtext)
        has_asc = re.search('[tidfhjklb]', wtext)
        if has_caps:
            guess, quality = wheight, 'good'
        elif has_asc:
            guess, quality = wheight, 'good'
        else:
            guess, quality = wheight * 1.3, 'bad'
        if not re.match('[A-Za-z\-\.\,\;]+$', wtext):
            # special characters like ( or ' interfere with font size estimation
            quality = 'terrible'
        debug(5, '    fontsize estimate %s credibility %s', guess, quality)
        fontsize_guesses[quality].append(guess)

    debug(5, 'line height: %s', round(height))
    ret = {
        'left': round(left),
        'top': round(top),
        'width': round(right-left),
        'height': round(height)
    }
    if fontsize_guesses['good']:
        guesses = fontsize_guesses['good']
        plusminus = 1/10
    elif fontsize_guesses['bad']:
        guesses = fontsize_guesses['bad']
        plusminus = 1/7
    elif fontsize_guesses['terrible']:
        guesses = fontsize_guesses['terrible']
        plusminus = 1/5
    else:
        debug(4, 'no font size guesses on line?!')
        guesses = [20]
        plusminus = 1
    fontsize = median(guesses)
    variability = stdev(guesses) if len(guesses) > 1 else 0
    fontsize_plusminus = fontsize*plusminus + variability/2
    debug(5, 'font size guess: %s, guesses stdev: %s, plusminus: %s', 
          fontsize, variability, fontsize_plusminus)
    ret['fontsize'] = fontsize
    ret['fontsize_plusminus'] = fontsize_plusminus
    return ret

if __name__ == "__main__":

    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG)
    logger.addHandler(ch)

    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('infile', help='filename of pdf to ocr')
    ap.add_argument('outfile', help='filename for xml output')
    ap.add_argument('-d', '--debug_level', default=1, type=int)
    ap.add_argument('--keep', action='store_true', help='keep temporary files')
    ap.add_argument('--hocr', action='store_true', help='write hocr output to outfile')
    args = ap.parse_args()

    ocr2xml(args.infile, args.outfile, 
            debug_level=args.debug_level,
            keep_tempfiles=args.keep,
            write_hocr=args.hocr)

