#!/usr/bin/env python



import pygtk
import gtk
import numpy
import Image
import StringIO
import sys
import re


pygtk.require('2.0')


def image_viewport(a):
    "Return a GTK image object showing a given numpy array of 0..255 values."
    assert len(a.shape) == 2
    if a.shape[0] == 0 or a.shape[1] == 0:
        return gtk.Image()

    # get a PIL image
    image = Image.fromarray(a.astype('uint8'))

    # get a PPM image in a memory buffer
    file = StringIO.StringIO()
    image.save(file, 'ppm')
    contents = file.getvalue()
    file.close()

    # get a GDK pixbuf
    loader = gtk.gdk.PixbufLoader('pnm')
    loader.write(contents, len(contents))
    pixbuf = loader.get_pixbuf()
    loader.close()

    # get a GTK Image
    result = gtk.Image()
    result.set_from_pixbuf(pixbuf)
    result.show()
    return result


def labeled_image_viewport(a, text):
    "Return a widget showing the given numpy array of (0..255) and the caption."
    vbox = gtk.VBox()
    vbox.show()
    vbox.add(image_viewport(a))
    label = gtk.Label(text)
    label.show()
    vbox.add(label)
    return vbox
    

def crop_x(image):
    "Return a subimage with X margins equal to 255 are removed; may return None"
    m = image == 255
    if m.all():
        return None
    px = m.all(axis=0) == False
    px = numpy.arange(len(px))[px]
    #py = m.all(axis=1) == False
    #py = numpy.arange(len(py))[py]
    return image[:, px.min():px.max()]


def subimage_x(seg, i):
    "Extract the i-th character from the segmentation; might return None"
    a = numpy.zeros(seg.shape)
    a[seg != i] = 255
    return crop_x(a)


def segmentation_viewport(seg, transcript):
    "Return a widget showing a segmentation as a set of labeled subimages"
    hbox = gtk.HBox()
    hbox.show()
    seg[seg == 0xFFFFFF] = 0
    seg &= 0xFFF
    n = seg.max()
    for i in range(n):
        img = subimage_x(seg, i + 1)
        if img != None:
            if i < len(transcript):
                text = transcript[i]
            else:
                text = ''
            viewport = labeled_image_viewport(img, text)
            hbox.pack_start(viewport, padding=10)
    return hbox


def load_segmentation(path):
    "Load a segmentation as an array of ints (as read_png_rgb() would do)"
    seg = numpy.asarray(Image.open(path)).astype('int32')
    return (seg[:,:,0] << 16) | seg[:,:,1] << 8 | seg[:,:,2]    


current_arg = 1


def on_key_press(widget, event):
    global current_arg
    assert event.type == gtk.gdk.KEY_PRESS
    if event.keyval == gtk.keysyms.Page_Up:
        current_arg -= 1
        if current_arg == 0:
            current_arg = len(sys.argv) - 1
        fill_segmentation_window(widget, sys.argv[current_arg])
        
    elif event.keyval == gtk.keysyms.Page_Down:
        current_arg += 1
        if current_arg == len(sys.argv):
            current_arg = 1
        fill_segmentation_window(widget, sys.argv[current_arg])


def fill_segmentation_window(window, segmentation_path):
    transcript_path = re.sub('(\.seg|\.cut)?\.png$','.txt', segmentation_path)
    seg = load_segmentation(segmentation_path)
    f = open(transcript_path)
    transcript = f.read().replace(' ','')
    f.close()
    if window.child != None:
        window.remove(window.child)
    window.add(segmentation_viewport(seg, transcript))
    window.set_title(segmentation_path)
    
    

def segmentation_viewer():
    window = gtk.Window(gtk.WINDOW_TOPLEVEL)
    window.connect("delete_event", lambda widget, event: gtk.main_quit())
    window.connect("key_press_event", on_key_press)
    window.show()
    return window


if __name__ == "__main__":
    if len(sys.argv) == 1:
        print "Usage: %s <segmentation file>" % sys.argv[0]
        sys.exit(2)
    viewer = segmentation_viewer()
    fill_segmentation_window(viewer, sys.argv[1])
    gtk.main()

