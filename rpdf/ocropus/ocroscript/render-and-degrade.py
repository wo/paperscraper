#! /usr/bin/python

from PIL import Image, ImageFont, ImageDraw
from numpy import *
from scipy import ndimage
import os, sys
from random import randrange
from numpy.random import random_sample, standard_normal

def render(text, font,w=None,h=130):
    if not w:
        w = h * len(text)
    image = Image.new("L", (w,h), 255)
    draw = ImageDraw.Draw(image)
    # without that space before the text, some letters look cut a little
    draw.text((0, 0), ' ' + text, font=font)
    del draw
    return double(asarray(image))

def elastic_transform_map(shape, alpha=6, sigma=4):
    a = alpha * (2 * random_sample(shape) - 1)
    return ndimage.gaussian_filter(a, sigma)

def elastic_transform(image, alpha=6, sigma=4):
    d0 = elastic_transform_map(image.shape, alpha, sigma)
    d1 = elastic_transform_map(image.shape, alpha, sigma)
    def coord_map(coord):
        return coord[0] + d0[coord[0],coord[1]], \
               coord[1] + d1[coord[0],coord[1]]
    return ndimage.geometric_transform(image, coord_map)

def jitter(image, mean, sigma):
    d0 = standard_normal(image.shape) * sigma + mean
    d1 = standard_normal(image.shape) * sigma + mean
    def coord_map(coord):
        return coord[0] + d0[coord[0],coord[1]], \
               coord[1] + d1[coord[0],coord[1]]
    return ndimage.geometric_transform(image, coord_map)

def adjust_sensitivity(image, mean, sigma):
    return image - 255 * (standard_normal(image.shape) * sigma + mean)
    
def threshold(image, mean, sigma):
    t = 255 - 255 * (standard_normal(image.shape) * sigma + mean)
    return where(image < t, 0, 255)
    
def degrade(image, elastic_alpha=6, elastic_sigma=4, 
                   jitter_mean=.2, jitter_sigma=.1,
                   sensitivity_mean=.125, sensitivity_sigma=.04,
                   threshold_mean=.4, threshold_sigma=.04):
    t = elastic_transform(255 - image, alpha=elastic_alpha, sigma=elastic_sigma)
    t = 255 - jitter(t, jitter_mean, jitter_sigma)
    t = adjust_sensitivity(t, sensitivity_mean, sensitivity_sigma)
    return threshold(t, threshold_mean, threshold_sigma)

def render_and_degrade(text, font):
    return degrade(ndimage.zoom(render(text, font), .3))

if len(sys.argv) != 5:
    print "Usage: render-and-degrade.py <word-list> <font.ttf> <quantity> <output>"
    exit(1)

letters = open(sys.argv[1]).readlines()
from pylab import *
from random import randrange
import codecs
font_name = sys.argv[2]
prefix = sys.argv[4] + ".files"
list = open(sys.argv[4], "w")
font = ImageFont.truetype(font_name, 100)
if not os.path.isdir(prefix):
    os.mkdir(prefix)
N = int(sys.argv[3])

for counter in range(N):
    i = randrange(len(letters))
    letter = render_and_degrade(letters[i].rstrip(), font)
    #letter = ndimage.zoom(letter, .3)
    min_letter = letter.min()
    max_letter = letter.max()
    letter = 255 * (letter - min_letter) / (max_letter - min_letter)
    #a=zeros(letter.shape+(3,))
    #a[:,:,0] = a[:,:,1] = letter
    #letter[letter==0] = 1 # make it segmentation-compatible
    #a[:,:,2] = letter
    filename = "%s/%05d" % (prefix, counter)
    Image.fromarray(letter.astype('uint8'), 'L').save(filename + '.png')
    transcript = codecs.open(filename + '.txt', 'w', 'utf-8')
    transcript.write(letters[i].rstrip())
    transcript.write('\n')
    transcript.close()
    list.write(filename + '.png ' + filename + '.txt\n')
list.close()
