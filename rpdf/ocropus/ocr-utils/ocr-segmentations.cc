// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
// or its licensors, as applicable.
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
// Project:
// File: ocr-utils.cc
// Purpose: miscelaneous routines
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "sysutil.h"
#include "ocr-utils.h"
#include "ocr-segmentations.h"

using namespace imglib;
using namespace colib;

namespace {
    // moved that to private because I think there's a function that does
    // a better job by looking not at all pixels, but only at the boundary.
    //  -- IM
    // FIXME: get rid of this function
    static bool line_is_inverted(bytearray &line_mask, bytearray &gray_line) {
        ASSERT(samedims(line_mask, gray_line));
        double s0 = 0, s255 = 0;
        int c0 = 0, c255 = 0;
        for(int i = 0; i < gray_line.length1d(); i++) {
            if(line_mask.at1d(i)) {
                s255 += gray_line.at1d(i);
                c255++;
            } else {
                s0 += gray_line.at1d(i);
                c0++;
            }
        }
        return s255 * c0 < s0 * c255;
    }
}

namespace ocropus {

    void set_line_number(intarray &a, int lnum) {
        lnum <<= 12;
        for(int i = 0; i < a.length1d(); i++) {
            if (a.at1d(i) && a.at1d(i) != 0xFFFFFF)
                a.at1d(i) = (a.at1d(i) & 0xFFF) | lnum;
        }
    }

    // FIXME comments

    void extract_lines(narray<bytearray> &lines,narray<rectangle> &rboxes,intarray &image) {
        //int minwidth = 10, minheight = 10;
        check_page_segmentation(image);
        int padding = 3;
        inthash<rectangle> bboxes;
        for(int i=0;i<image.dim(0);i++) for(int j=0;j<image.dim(1);j++) {
            int pixel = image(i,j);
            if ((pixel & 0xFFFF00) == 0xFFFF00)
                continue;
            rectangle &r = bboxes(pixel);
            r.include(i,j);
        }
        intarray keys;
        bboxes.keys(keys);
        quicksort(keys);
        lines.resize(keys.length());
        rboxes.resize(keys.length());
        for(int ki=0;ki<keys.length();ki++) {
            int key = keys[ki];
            rectangle box = bboxes(key);
            rboxes[ki].x0 = max(0, box.x0 - padding);
            rboxes[ki].y0 = max(0, box.y0 - padding);
            rboxes[ki].x1 = min(image.dim(0), box.x1 + padding);
            rboxes[ki].y1 = min(image.dim(1), box.y1 + padding);
            //if(box.width()<minwidth || box.height()<minheight) continue; // we'd better check for empty lines in LA
            bytearray line(rboxes[ki].width(),rboxes[ki].height());
            fill(line, 255);
            int dx = box.x0 - rboxes[ki].x0;
            int dy = box.y0 - rboxes[ki].y0;
            for(int i=0;i<box.width();i++) for(int j=0;j<box.height();j++) {
                if (image(i+box.x0,j+box.y0) == key)
                    line(i+dx,j+dy) = 0;
            }
            //pad_by(line,padding,padding,0);
            ASSERT(line.dim(0) > 0 && line.dim(1) > 0);
            move(lines[ki],line);
        }
    }

    // FIXME comments

    void rescale_if_needed(bytearray &bin_line,
                           bytearray &gray_line) {
        enum {MIN_HEIGHT=40};
        enum {MAX_HEIGHT=100};

        ASSERT(samedims(bin_line, gray_line));
        int new_height;
        if(gray_line.dim(1) < MIN_HEIGHT)
            new_height = MIN_HEIGHT;
        else if(gray_line.dim(1) > MAX_HEIGHT)
            new_height = MAX_HEIGHT;
        else
            return;

        bytearray new_gray_line;
        bytearray new_bin_line;
        floatarray tmp;
        copy(tmp, bin_line);
        dilate_2(tmp, 1);
        copy(bin_line, tmp);
        rescale_to_height(new_gray_line, gray_line, new_height);
        rescale_to_height(new_bin_line, bin_line, new_height);
        move(gray_line, new_gray_line);
        move(bin_line, new_bin_line);

        // make a new line mask - that's not trivial
        int threshold = (min(gray_line) + max(gray_line)) / 2;
        if (line_is_inverted(bin_line, gray_line)) {
            for(int i = 0; i < gray_line.length1d(); i++) {
                if(gray_line.at1d(i) > threshold && bin_line.at1d(i) != 255)
                    bin_line.at1d(i) = 0;
                else
                    bin_line.at1d(i) = 255;
            }
        } else {
            for(int i = 0; i < gray_line.length1d(); i++) {
                if(gray_line.at1d(i) < threshold && bin_line.at1d(i) != 255)
                    bin_line.at1d(i) = 0;
                else
                    bin_line.at1d(i) = 255;
            }
        }
    }

    // FIXME comments

    void normalize_segmentation(intarray &segmentation, bytearray &line_mask) {
        ASSERT(samedims(line_mask, segmentation));
        make_line_segmentation_black(segmentation);
        if(!contains_only(segmentation, 0)) {
            propagate_labels(segmentation);
        }
        for(int i = 0; i < segmentation.length1d(); i++) {
            if (line_mask.at1d(i))   
                segmentation.at1d(i) = 0;
        }
    }

    /// Blit the segmentation of src onto dst shifted by (x,y) and shifted by
    /// values by max(dst).
    void concat_segmentation(colib::intarray &dst, colib::intarray &src,
                             int x, int y) {
        int d = max(dst);
        int i_min = max(0, -x);
        int j_min = max(0, -y);
        int i_cap = min(src.dim(0), dst.dim(0) - x);
        int j_cap = min(src.dim(1), dst.dim(1) - y);
        for(int i = i_min; i < i_cap; i++)
            for(int j = j_min; j < j_cap; j++)
                if(src(i,j) && src(i,j) != 0xFFFFFF)
                    dst(i+x,j+y) = src(i, j) + d;
    }


    bool has_no_black_pixels(intarray &a) {
        for(int i = 0; i < a.length1d(); i++) {
            if(!a.at1d(i))
                return false;
        }
        return true;
    }

    // FIXME comments

    void blit_segmentation_line(intarray &page,
                                rectangle bbox, 
                                intarray &line,
                                int line_no) {
        check_line_segmentation(line);
        ASSERT(line.dim(0) == bbox.width());
        ASSERT(line.dim(1) == bbox.height());
        line_no++;
        for(int x = 0; x < line.dim(0); x++) {
            for(int y = 0; y < line.dim(1); y++) {
                if(line(x,y) != 0xFFFFFF) {
                    page(x + bbox.x0, y + bbox.y0) =
                        (line_no << 12) | (line(x, y) & 0xFFF);
                }
            }
        }
    }

    // FIXME comments

    int max_cnum(intarray &seg) {
        int result = 0;
        for(int i = 0; i < seg.length1d(); i++) {
            if (seg.at1d(i) == 0xFFFFFF) continue;
            int cnum = seg.at1d(i) & 0xFFF;
            if(cnum > result)
                result = cnum;
        }
        return result;
    }

    // FIXME comments

    void forget_segmentation(bytearray &image, intarray &segmentation) {
        check_line_segmentation(segmentation);
        makelike(image, segmentation);
        for(int i=0; i<image.length1d(); i++) {
            int pixel = segmentation.at1d(i);
            image.at1d(i) = (pixel == 0xFFFFFF || pixel == 0) ? 255 : 0;
        }
    }

    // FIXME comments

    void check_line_segmentation(intarray &cseg,bool allow_zero,bool allow_gaps,bool allow_lzero) {
        narray<bool> used(5000);
        fill(used,false);
        int nused = 0;
        int mused = 0;
        for(int i=0;i<cseg.length1d();i++) {
            unsigned pixel = (unsigned)cseg.at1d(i);
            CHECK_ARG(allow_zero || pixel!=0);
            if(pixel==0 || pixel==0xffffff) continue;
            int cnum = (pixel & 0xfff);
            if(!used(cnum)) nused++;
            if(cnum>mused) mused = cnum;
            used(cnum) = true;
            unsigned lnum = (pixel >> 12);
            if(!allow_lzero) { CHECK_ARG(lnum==1); }
            else { CHECK_ARG(lnum==0 || lnum==1); }
        }
        // character segments need to be numbered sequentially (no gaps)
        // (gaps usually happen when someone passes a binary image instead of a segmentation)
        if(!allow_gaps) CHECK_ARG(nused>=mused);
    }

    // FIXME comments

    void check_page_segmentation(intarray &pseg,bool allow_zero) {
        narray<bool> used(5000);
        fill(used,false);
        int nused = 0;
        int mused = 0;
        for(int i=0;i<pseg.length1d();i++) {
            unsigned pixel = (unsigned)pseg.at1d(i);
            CHECK_ARG(allow_zero || pixel!=0);
            if(pixel==0 || pixel==0xffffff) continue;
            int column = 0xff & (pixel >> 16);
            int paragraph = 0xff & (pixel >> 8);
            int line = 0xff & pixel;
            CHECK_ARG((column > 0 && column < 32) || column == 254 || column == 255);
            CHECK_ARG((paragraph >= 0 && paragraph < 64) || (paragraph >=251 && paragraph <= 255));
            if (column < 32) {
                if(!used(line)) nused++;
                used(line) = true;
                if(line>mused) mused = line;
            }
        }
        // character segments need to be numbered sequentially (no gaps)
        // (gaps usually happen when someone passes a binary image instead of a segmentation)
        CHECK_ARG(nused==mused || nused==mused+1);
    }

    // FIXME comments

    void get_recoloring_map(intarray &recolor, intarray &image) {
        make_line_segmentation_black(image, true);
        narray<bool> used(max(image) + 1);
        fill(used, false);
        for(int i = 0; i < image.length1d(); i++)
            used[image.at1d(i)] = true;
        makelike(recolor, used);
        fill(recolor, 0);
        int color = 1;
        for(int i = 1; i < used.length(); i++) {
            if (used[i])
                recolor[i] = color++;
        }
    }

    // FIXME comments

    void remove_gaps_by_recoloring(intarray &image) {
        intarray map;
        get_recoloring_map(map, image);
        for(int i = 0; i < image.length1d(); i++)
            image.at1d(i) = map[image.at1d(i)];
        
    }
    
    // FIXME comments

    void make_line_segmentation_black(intarray &a,bool allow_gaps,bool allow_lzero) {
        check_line_segmentation(a,true,allow_gaps, allow_lzero);
        replace_values(a, 0xFFFFFF, 0);
        for(int i = 0; i < a.length1d(); i++)
            a.at1d(i) &= 0xFFF;
    }

    // FIXME comments

    void make_line_segmentation_white(intarray &a) {
        replace_values(a, 0, 0xFFFFFF);
        // FIXME should not give gaps
        //for(int i = 0; i < a.length1d(); i++)
        //    a.at1d(i) = (a.at1d(i) & 0xFFF) | 0x1000;
        check_line_segmentation(a);
    }

    // FIXME comments

    void make_page_segmentation_black(intarray &a) {
        check_page_segmentation(a,false);
        replace_values(a, 0xFFFFFF, 0);
    }
    
    // FIXME comments

    void make_page_segmentation_white(intarray &a) {
        replace_values(a, 0, 0xFFFFFF);
        check_page_segmentation(a);
    }

    static int pick_threshold(intarray &segmentation, bytearray &image, int k) {
        int min = 255;//, max = 0;
        int n = segmentation.length1d();
        for(int i = 0; i < n; i++) {
            if(segmentation.at1d(i) == k) {
                int pixel = image.at1d(i);
                if(pixel < min) min = pixel;
                //if(pixel > max) max = pixel;
            }
        }
        if(min > 128)
            return min;
        else
            return 128;
    }

    void binarize_in_segmentation(intarray &segmentation, bytearray &gray_image) {
        CHECK_ARG(samedims(segmentation, gray_image));
        // should be passed a valid segmentation
        check_line_segmentation(segmentation,true);
        int n = segmentation.length1d();
        intarray thresholds(1);
        for(int i = 0; i < n; i++) {
            int c = segmentation.at1d(i);
            if(c == 0 || c == 0xFFFFFF)
                continue;
            c &= 0xFFF; // clear the line number
            while(c >= thresholds.length()) {
                thresholds.push(pick_threshold(segmentation, 
                                               gray_image, 
                                               thresholds.length()));
            }
            if(gray_image.at1d(i) > thresholds[c])
                 segmentation.at1d(i) = 0xFFFFFF;
        }            
        // should return a valid segmentation
        check_line_segmentation(segmentation,true);
    }


}
