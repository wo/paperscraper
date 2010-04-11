// -*- C++ -*-

// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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
// File: ocr-utils.h
// Purpose: miscelaneous routines
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

/// \file ocr-utils.h
/// \brief Miscelaneous routines

#ifndef h_ocr_segmentations_
#define h_ocr_segmentations_

#include "colib.h"
#include "imglib.h"
#include "sysutil.h"
#include "idmap.h"

namespace ocropus {
    /// Assert that all items of this array of arrays are not empty.
    template<class T>
    void assert_all_items_nonempty(colib::narray<colib::narray<T> > &a) {
        for(int i=0;i<a.length();i++)
            ASSERT(a[i].length1d() > 0);
    }

    /// Remove from the segmentation those pixels which are white in gray_image.
    void binarize_in_segmentation(colib::intarray &segmentation, /* const */ colib::bytearray &gray_image);
    
    /// Set line number for all foreground pixels in a character segmentation.
    void set_line_number(colib::intarray &a, int lnum);


    /// Unpack page segmentation into separate line masks with bounding boxes.
    void extract_lines(colib::narray<colib::bytearray> &lines,colib::narray<colib::rectangle> &rboxes,colib::intarray &image);

    /// If the line is too small or too large, rescale it (with the mask)
    /// to a decent height (30-60 pixels).
    void rescale_if_needed(colib::bytearray &bin_line, colib::bytearray &gray_line);

    /// Make a binary image from a line segmentation.
    void forget_segmentation(colib::bytearray &image, colib::intarray &segmentation);

    /// Return true if there are no zeros in the array.
    bool has_no_black_pixels(colib::intarray &);

    void blit_segmentation_line(colib::intarray &page,
                                colib::rectangle bbox, 
                                colib::intarray &line,
                                int line_no);

    /// Blit the segmentation of src onto dst shifted by (x,y) and shifted by
    /// values by max(dst).
    void concat_segmentation(colib::intarray &dst, colib::intarray &src,
                             int x, int y);

    // Enlarge segmentation and AND it with line_mask.
    // Don't pass binarized grayscale image as line_mask,
    // otherwise you might get debris not from the line.
    // (that means we cannot really call this from inside LineOCR)
    void normalize_segmentation(colib::intarray &segmentation, colib::bytearray &line_mask);

    int max_cnum(colib::intarray &seg);

    // FIXME use these creation/accessor functions more widely

    inline int pseg_pixel(int column,int paragraph,int line) {
        ASSERT((column > 0 && column < 32) || column == 254 || column == 255);
        ASSERT((paragraph >= 0 && paragraph < 64) || (paragraph >=251 && paragraph <= 255));
        ASSERT(line>=0 && line<256);
        return (column<<16) | (paragraph<<8) | line;
    }

    inline int pseg_pixel(int column,int line) {
        ASSERT(column>0 && column<32);
        ASSERT(line>=0 && line<64*256);
        return (column<<16) | line;
    }

    inline int pseg_column(int pixel) {
        return (pixel>>16)&0xff;
    }

    inline int pseg_paragraph(int pixel) {
        return (pixel>>8) & 0x3f;
    }

    inline int pseg_line(int pixel) {
        return pixel & 0xff;
    }

    inline int pseg_pline(int pixel) {
        return pixel & 0x3fff;
    }

    inline int cseg_pixel(int chr) {
        ASSERT(chr>0 && chr<4096);
        return (1<<12) | chr;
    }
    
    inline void pseg_columns(colib::intarray &a) {
        for(int i=0;i<a.length1d();i++) {
            int value = a.at1d(i);
            if(value==0xffffff) value = 0;
            value = pseg_column(value);
            if(value>=32) value = 0;
            a.at1d(i) = value;
        }
    }

    inline void pseg_plines(colib::intarray &a) {
        for(int i=0;i<a.length1d();i++) {
            int value = a.at1d(i);
            if(value==0xffffff) value = 0;
            if(pseg_column(value)>=32) value = 0;
            value = pseg_pline(value);
            a.at1d(i) = value;
        }
    }

    void check_line_segmentation(colib::intarray &cseg,bool allow_zero=true,bool allow_gaps=true,bool allow_lzero=true);
    void check_page_segmentation(colib::intarray &cseg,bool allow_zero=true);
    void make_line_segmentation_black(colib::intarray &a,bool allow_gaps=true,bool allow_lzero=true);
    void get_recoloring_map(colib::intarray &recolor, colib::intarray &image);
    void remove_gaps_by_recoloring(colib::intarray &image);
    void make_line_segmentation_white(colib::intarray &a);
    void make_page_segmentation_black(colib::intarray &a);
    void make_page_segmentation_white(colib::intarray &a);

    void evaluate_segmentation(int &nover,int &nunder,int &nmis,colib::intarray &model_raw,colib::intarray &image_raw,float tolerance);
    void align_segmentation(colib::intarray &segmentation,colib::narray<colib::rectangle> &bboxes);
    void idmap_of_correspondences(idmap &result,colib::intarray &charseg,colib::intarray &overseg);
    void idmap_of_bboxes(idmap &result,colib::intarray &segmentation,colib::narray<colib::rectangle> &bboxes);
    void segmentation_to_cseg(colib::intarray &cseg,idmap &map,colib::intarray &ids,colib::intarray &segmentation);
    void ocr_result_to_charseg(colib::intarray &cseg,idmap &map,colib::intarray &ids,colib::intarray &segmentation,bool map_all=true);
    void ocr_bboxes_to_charseg(colib::intarray &cseg,colib::narray<colib::rectangle> &bboxes,colib::intarray &segmentation);
}

#endif
