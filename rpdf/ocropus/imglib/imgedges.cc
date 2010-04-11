// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// Copyright 1992-2005 Thomas M. Breuel
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
// File: imgedges.cc
// Purpose: edge-detection related operations
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

extern "C" {
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
}
;

#include "colib.h"
#include "imglib.h"


using namespace colib;

namespace imglib {

    template<class T> inline T isign(T x) {
        return ((x)>=0 ? 1 : -1);
    }

    /// Nonmaximum suppression for Canny edge detector.
    /// @param out - resulting black-and-white image (white edges on black)
    /// @param gradm - the lengths of the vectors in the field (gradx, grady)
    static void nonmaxsup(bytearray &out, floatarray &gradm, floatarray &gradx,
            floatarray &grady) {
        int w = gradm.dim(0), h = gradm.dim(1);
        out.resize(w, h);
        fill(out, 0);
        for (int i=1; i<w-1; i++) {
            for (int j=1; j<h-1; j++) {
                float dx=gradx(i, j);
                float ux=fabs(dx);
                float dy=grady(i, j);
                float uy=fabs(dy);
                int bx=int(isign(dx));
                int by=int(isign(dy));
                int ax=bx*(ux>uy);
                int ay=by*(ux<=uy);
                float vx, vy;
                if (ax) {
                    vy=ux;
                    vx=uy;
                } else {
                    vx=ux;
                    vy=uy;
                }
                float c=gradm(i, j);
                float u=gradm(i-ax, j-ay);
                float d=gradm(i-bx, j-by);
                if (vy*c<=(vx*d+(vy-vx)*u))
                    continue;
                u=gradm(i+ax, j+ay);
                d=gradm(i+bx, j+by);
                if (vy*c<(vx*d+(vy-vx)*u))
                    continue;
                out(i, j)=255;
            }
        }
    }

    /// Compute raw edges from image, including non-maximum suppression.
    /// Pixels not corresponding to edges are set to 0, edge pixels
    /// are set to their gradient strength, which is always >0.
    void rawedges(floatarray &gradm, floatarray &smoothed) {
        int w = smoothed.dim(0);
        int h = smoothed.dim(1);

        floatarray gradx, grady;
        bytearray uedges;

        gradm.resize(w, h);
        gradx.resize(w, h);
        grady.resize(w, h);
        fill(gradm, 0.0);
        fill(gradx, 0.0);
        fill(grady, 0.0);
        for (int i=w-2; i>=0; i--)
            for (int j=h-2; j>=0; j--) {
                float v = smoothed(i, j);
                float dx = smoothed(i+1, j)-v;
                float dy = smoothed(i, j+1)-v;
                gradx(i, j) = dx;
                grady(i, j) = dy;
                gradm(i, j) = sqrt(sqr(dx)+sqr(dy));
            }

        nonmaxsup(uedges, gradm, gradx, grady);
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++)
                if (!uedges(i, j))
                    gradm(i, j) = 0;
    }

    /// Compute a fractile of the non-zero pixels in the image.

    float nonzero_fractile(floatarray &gradm, float frac, int bins) {
        intarray hist(bins);
        fill(hist, 0);
        float minv=1e30, maxv=-1e30;
        int count=0;
        for (int i=0, n=gradm.length1d(); i<n; i++) {
            if (gradm.at1d(i)==0.0)
                continue;
            count++;
            if (maxv<gradm.at1d(i))
                maxv=gradm.at1d(i);
            if (minv>gradm.at1d(i))
                minv=gradm.at1d(i);
        }
        if (count<2)
            return minv;
        if (maxv==minv)
            return minv;
        int limit=int(frac*count);
        float scale = bins / (maxv - minv);
        for (int i=0, n=gradm.length1d(); i<n; i++) {
            if (gradm.at1d(i)==0.0)
                continue;
            int bin = int(scale*(gradm.at1d(i)-minv));
            hist(min(bins-1, bin))++;
        }
        int i=0, sum=0;
        for (; i<bins&&sum<limit; i++) {
            sum+=hist(i);
        }
        return (maxv-minv)*i/bins+minv;
    }

    static void masked_fill(floatarray &image, int x, int y) {
        int w = image.dim(0), h = image.dim(1);
        if (x<0 || x>=w || y<0 || y>=h)
            return;
        if (image(x, y)==3 || image(x, y)==0)
            return;
        image(x, y)=3;
        masked_fill(image, x+1, y);
        masked_fill(image, x, y+1);
        masked_fill(image, x-1, y);
        masked_fill(image, x, y-1);
        masked_fill(image, x+1, y+1);
        masked_fill(image, x-1, y+1);
        masked_fill(image, x-1, y+1);
        masked_fill(image, x+1, y-1);
    }

    /// Perform hysteresis thresholding of the image, using the given tlow and thigh thresholds.

    void hysteresis_thresholding(floatarray &image, float tlow, float thigh) {
        int w = image.dim(0), h = image.dim(1);
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                if (image(i, j)>=thigh)
                    image(i, j) = 2;
                else if (image(i, j)>=tlow)
                    image(i, j) = 1;
                else
                    image(i, j) = 0;

            }
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                if (image(i, j)==2)
                    masked_fill(image, i, j);
            }
        for (int i=0; i<w; i++)
            for (int j=0; j<h; j++) {
                if (image(i, j)==3)
                    image(i, j) = 1;
                else if (image(i, j)==1)
                    image(i, j) = 0.5;
                else
                    image(i, j) = 0;
            }
    }
}
