// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
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
// File: imgmorph.cc
// Purpose: simple grayscale morphology based on local min/max
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

extern "C" {
#include <math.h>
}

#include "colib.h"
#include "imglib.h"


using namespace colib;

namespace imglib {

    inline byte bc(int c) {
        if (c<0)
            return 0;
        if (c>255)
            return 255;
        return c;
    }

    void make_boolean(bytearray &image) {
        for (int i=0; i<image.length1d(); i++)
            image.at1d(i) = image.at1d(i) ? 255 : 0;
    }

    void complement(bytearray &image) {
        for (int i=0; i<image.length1d(); i++)
            image.at1d(i) = 255-image.at1d(i);
    }

    void difference(bytearray &image, bytearray &image2, int dx, int dy) {
        int w = image.dim(0);
        int h = image.dim(1);
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                image.unsafe_at(i, j) = bc(abs(image(i, j)-ext(image2, i-dx, j
                        -dy)));
            }
    }

    int maxdifference(bytearray &image, bytearray &image2, int cx, int cy) {
        CHECK_ARG(samedims(image, image2));
        int w = image.dim(0);
        int h = image.dim(1);
        int d = 0;
        for (int i=cx; i<w-cx; i++)
            for (int j=cy; j<h-cy; j++) {
                d = max(d, image(i, j)-image2(i, j));
            }
        return d;
    }

    void minshift(bytearray &image, bytearray &image2, int dx, int dy) {
        int w = image.dim(0);
        int h = image.dim(1);
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                image.at(i, j) = min(image(i, j), ext(image2, i-dx, j-dy));
            }
    }

    void maxshift(bytearray &image, bytearray &image2, int dx, int dy) {
        int w = image.dim(0);
        int h = image.dim(1);
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                image.at(i, j) = max(image.at(i, j), ext(image2, i-dx, j-dy));
            }
    }

    void erode_circle(bytearray &image, int r) {
        if (r==0)
            return;
        bytearray out;
        copy(out, image);
        for (int i=-r; i<=r; i++)
            for (int j=-r; j<=r; j++) {
                if (i*i+j*j<=r*r)
                    minshift(out, image, i, j);
            }
        move(image, out);
    }

    void dilate_circle(bytearray &image, int r) {
        if (r==0)
            return;
        bytearray out;
        copy(out, image);
        for (int i=-r; i<=r; i++)
            for (int j=-r; j<=r; j++) {
                if (i*i+j*j<=r*r)
                    maxshift(out, image, i, j);
            }
        move(image, out);
    }

    void open_circle(bytearray &image, int r) {
        if (r==0)
            return;
        erode_circle(image, r);
        dilate_circle(image, r);
    }

    void close_circle(bytearray &image, int r) {
        if (r==0)
            return;
        dilate_circle(image, r);
        erode_circle(image, r);
    }

    void erode_rect(bytearray &image, int rw, int rh) {
        if (rw==0&&rh==0)
            return;
        bytearray out;
        copy(out, image);
        for (int i=0; i<rw; i++)
            minshift(out, image, i-rw/2, 0);
        for (int j=0; j<rh; j++)
            minshift(image, out, 0, j-rh/2);
    }

    void dilate_rect(bytearray &image, int rw, int rh) {
        if (rw==0&&rh==0)
            return;
        bytearray out;
        copy(out, image);
        // note that we handle the even cases complementary
        // to erode_rect; this makes open_rect and close_rect
        // do the right thing
        for (int i=0; i<rw; i++)
            maxshift(out, image, i-(rw-1)/2, 0);
        for (int j=0; j<rh; j++)
            maxshift(image, out, 0, j-(rh-1)/2);
    }

    void open_rect(bytearray &image, int rw, int rh) {
        if (rw==0&&rh==0)
            return;
        erode_rect(image, rw, rh);
        dilate_rect(image, rw, rh);
    }

    void close_rect(bytearray &image, int rw, int rh) {
        if (rw==0&&rh==0)
            return;
        dilate_rect(image, rw, rh);
        erode_rect(image, rw, rh);
    }

    // general gray scale morphology; note that the value of the mask matters
    // (but all of this reduces to binary morphology if the values of the image and
    // mask are 0 or 255)

    void minshift(bytearray &image, bytearray &image2, int dx, int dy,
            byte offset) {
        int w = image.dim(0);
        int h = image.dim(1);
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                image.at(i, j) = min(image(i, j), bc(ext(image2, i-dx, j-dy)
                        +(255-offset)));
            }
    }

    void maxshift(bytearray &image, bytearray &image2, int dx, int dy,
            byte offset) {
        int w = image.dim(0);
        int h = image.dim(1);
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                image.at(i, j) = max(image.at(i, j), bc(ext(image2, i-dx, j-dy)
                        -(255-offset)));
            }
    }

    void erode(bytearray &image, bytearray &mask, int cx, int cy) {
        bytearray out;
        copy(out, image);
        for (int i=0; i<mask.dim(0); i++)
            for (int j=0; j<mask.dim(1); j++) {
                byte value = mask(i, j);
                if (value)
                    minshift(out, image, i-cx, j-cy, value);
            }
        move(image, out);
    }

    void dilate(bytearray &image, bytearray &mask, int cx, int cy) {
        bytearray out;
        copy(out, image);
        for (int i=0; i<mask.dim(0); i++)
            for (int j=0; j<mask.dim(1); j++) {
                byte value = mask(i, j);
                if (value)
                    maxshift(out, image, i-cx, j-cy, value);
            }
        move(image, out);
    }

    void open(bytearray &image, bytearray &mask, int cx, int cy) {
        erode(image, mask, cx, cy);
        dilate(image, mask, cx, cy);
    }

    void close(bytearray &image, bytearray &mask, int cx, int cy) {
        dilate(image, mask, cx, cy);
        erode(image, mask, cx, cy);
    }

}
