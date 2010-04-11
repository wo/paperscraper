// -*- C++ -*-

// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// Copyright 1995-2005 Thomas M. Breuel
// 
// You may not use this file except under the terms of the accompanying license.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you
// may not use this file except in compliance with the License. You may
// obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
// Project: imglib -- image processing library
// File: imgmorph.h
// Purpose: interface to corresponding .cc file
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de
#ifndef h_imgmorph__
#define h_imgmorph__

#include "colib.h"

namespace imglib {

    void make_boolean(colib::bytearray &image);
    void complement(colib::bytearray &image);
    void difference(colib::bytearray &image, colib::bytearray &image2, int dx, int dy);
    int maxdifference(colib::bytearray &image, colib::bytearray &image2, int cx=0, int cy=0);
    void minshift(colib::bytearray &image, colib::bytearray &image2, int dx, int dy);
    void maxshift(colib::bytearray &image, colib::bytearray &image2, int dx, int dy);
    void erode(colib::bytearray &image, colib::bytearray &mask, int cx, int cy);
    void dilate(colib::bytearray &image, colib::bytearray &mask, int cx, int cy);
    void open(colib::bytearray &image, colib::bytearray &mask, int cx, int cy);
    void close(colib::bytearray &image, colib::bytearray &mask, int cx, int cy);
    void erode_circle(colib::bytearray &image, int r);
    void dilate_circle(colib::bytearray &image, int r);
    void open_circle(colib::bytearray &image, int r);
    void close_circle(colib::bytearray &image, int r);
    void erode_rect(colib::bytearray &image, int rw, int rh);
    void dilate_rect(colib::bytearray &image, int rw, int rh);
    void open_rect(colib::bytearray &image, int rw, int rh);
    void close_rect(colib::bytearray &image, int rw, int rh);

}

#endif
