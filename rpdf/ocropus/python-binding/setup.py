from distutils.core import setup, Extension
import re

f = open('../ocroscript/Jamfile')
subdirs = ['ocroscript']
re_subdir = re.compile('ImportDir *TOP *([-+A-Za-z ]*) *;')
for i in f:
    m = re_subdir.match(i)
    if m:
        subdirs.append(m.group(1).replace(' ', '/'))

subdirs_from_here = ['../' + x for x in subdirs]

ocropus = Extension('ocropus',
                    sources = ['ocropus-python.cc',
                               '../ocrocmd/version.cc'],

                    include_dirs = subdirs_from_here,
                    library_dirs = subdirs_from_here,
                    libraries = ['ocroscript', 'bpnet', 'roughocr',
                                 'glinerec', 'langmods', 'binarize',
                                 'tesseract', 'docclean', 'layoutrast',
                                 'deskewrast', 'textimageseg',
                                 'ocrutils', 'imgio', 'img', 'imgmorph',
                                 'lua', 'tolua++', 'png', 'jpeg',
                                 'SDL_gfx', 'SDL', 'edit', 'fst',
                                 'aspell', 'tesseract_full', 'tiff'])

setup (name = 'ocropus',
       version = '1.0',
       description = 'OCRopus bindings to Python',
       ext_modules = [ocropus])
