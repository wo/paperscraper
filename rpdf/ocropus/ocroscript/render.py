#! /usr/bin/python

from PIL import Image, ImageFont, ImageDraw
from numpy import *
from scipy import ndimage
import os, sys

def render(text, font,w=None,h=130):
    if not w:
        w = h * len(text)
    image = Image.new("L", (w,h), 255)
    draw = ImageDraw.Draw(image)
    # without that space before the text, some letters look cut a little
    draw.text((0, 0), ' ' + text, font=font)
    del draw
    return double(asarray(image))

if len(sys.argv) != 4:
    print "Usage: render.py <word-list> <font.ttf> <output>"
    exit(1)

letters = open(sys.argv[1]).readlines()
from pylab import *
from random import randrange
import codecs
font_name = sys.argv[2]
prefix = sys.argv[3] + ".files"
list = open(sys.argv[3], "w")
font = ImageFont.truetype(font_name, 100)
if not os.path.isdir(prefix):
    os.mkdir(prefix)
for i in range(len(letters)):
    current = letters[i].rstrip()
    letter = render(current, font)
    letter = ndimage.zoom(letter, .3)
    min_letter = letter.min()
    max_letter = letter.max()
    letter = 255 * (letter - min_letter) / (max_letter - min_letter)
    #a=zeros(letter.shape+(3,))
    #a[:,:,0] = a[:,:,1] = letter
    #letter[letter==0] = 1 # make it segmentation-compatible
    #a[:,:,2] = letter
    filename = "%s/%05d" % (prefix, i)
    Image.fromarray(letter.astype('uint8'), 'L').save(filename + '.png')
    transcript = codecs.open(filename + '.txt', 'w', 'utf-8')
    transcript.write(letters[i])
    transcript.close()
    list.write(filename + '.png ' + filename + '.txt\n')
    # print "#%d: %s" % (i + 1, current)
list.close()
