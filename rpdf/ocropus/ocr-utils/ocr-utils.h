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


#ifndef h_utils_
#define h_utils_


#include "colib.h"
#include "imglib.h"
#include "sysutil.h"
#include "narray-io.h"
#include "resource-path.h"

namespace ocropus {
    /// FIXME move into imglib
    /// Simply 255 - array.
    void invert(colib::bytearray &a);
    
    void crop_masked(colib::bytearray &result,
                     colib::bytearray &source,
                     colib::rectangle box,
                     colib::bytearray &mask,
                     int default_value, // where mask is false, also for padding
                     int padding = 0);

    int average_on_border(colib::bytearray &a);
    
    // Note that black and white are not mutually exclusive. FIXME?
    inline bool background_seems_black(colib::bytearray &a) {
        return average_on_border(a) <= 128;
    }
    inline bool background_seems_white(colib::bytearray &a) {
        return average_on_border(a) >= 128;
    }
    inline void make_background_white(colib::bytearray &a) {
        if(!background_seems_white(a))
            invert(a);
    }
    inline void make_background_black(colib::bytearray &a) {
        if(!background_seems_black(a))
            invert(a);
    }
    
    template<class T>
    void mul(colib::narray<T> &a, T coef) {
        for(int i = 0; i < a.length1d(); i++)
            a.at1d(i) *= coef;
    }

    /// Copy the `src' to `dest',
    /// moving it by `shift_x' to the right and by `shift_y' up.
    /// The image must fit.
    void blit2d(colib::bytearray &dest,
                const colib::bytearray &src,
                int shift_x = 0,
                int shift_y = 0);

    /// FIXME move into narray-util
    float median(colib::intarray &a);

    /// Estimate xheight given a slope and a segmentation.
    /// (That's an algorithm formerly used together with MLP).
    float estimate_xheight(colib::intarray &seg, float slope);

    void plot_hist(FILE *stream, colib::floatarray &hist);

    void draw_rects(colib::intarray &out, colib::bytearray &in,
                    colib::narray<colib::rectangle> &rects, 
                    int downsample_factor=1, int color=0x00ff0000);

    void draw_filled_rects(colib::intarray &out, colib::bytearray &in,
                           colib::narray<colib::rectangle> &rects,
                           int downsample_factor=1, 
                           int color=0x00ffff00, 
                           int border_color=0x0000ff00);

    void get_line_info(float &baseline, 
                       float &xheight, 
                       float &descender, 
                       float &ascender, 
                       colib::intarray &seg);

    const char *get_version_string();
    void set_version_string(const char *);
    
    // FIXME move into narray-util

    template<class T>
    bool contains_only(colib::narray<T> &a, T value) {
        for(int i = 0; i < a.length1d(); i++) {
            if(a.at1d(i) != value)
                return false;
        }
        return true;
    }
    
    template<class T>
    bool contains_only(colib::narray<T> &a, T value1, T value2) {
        for(int i = 0; i < a.length1d(); i++) {
            if(a.at1d(i) != value1 && a.at1d(i) != value2)
                return false;
        }
        return true;
    }

    struct Timers {
        Timer binarizer,cleanup,page_segmenter,line_segmenter,ocr,langmod;
        void report();
        void reset();
    };

    void report_ocr_timings();
    void reset_ocr_timings();
    Timers &get_ocr_timings();
    void normalize_input_classify(colib::floatarray &feature,colib::doublearray 
                                  &stdev,colib::doublearray &m_x);

    // FIXME move into narray-util

    template<class T>
    bool is_nan_free(T &v) {
        for(int i=0;i<v.length1d();i++)
            if(isnan(v.at1d(i)))
                return false;
        return true;
    }

    // FIXME redundant with rowutils.h

    template<class T>
    void extract_row(colib::narray<T> &row, colib::narray<T> &matrix, int index) {
        ASSERT(matrix.rank() == 1 || matrix.rank() == 2);
        if(matrix.rank() == 2) {
            row.resize(matrix.dim(1));
            for(int i = 0; i < row.length(); i++)
                row[i] = matrix(index, i);
        } else {
            row.resize(1);
            row[0] = matrix[index];
        }
    }

    // FIXME redundant with rowutils.h
    // Append a row to the 2D table.

    template<class T>
    void append_row(colib::narray<T> &table, colib::narray<T> &row) {
        ASSERT(row.length());
        if(!table.length1d()) {
            copy(table, row);
            table.reshape(1, table.length());
            return;
        }
        int h = table.dim(0);
        int w = table.dim(1);
        ASSERT(row.length() == w);
        table.reshape(table.total);
        table.grow_to(table.total + w);
        table.reshape(h + 1, w);
        for(int i = 0; i < row.length(); i++)
            table(h, i) = row[i];
    }

    // FIXME move into narray-utils

    template<class T>
    void get_dims(colib::intarray &dims, colib::narray<T> &a) {
        dims.resize(a.rank());
        for(int i = 0; i < dims.length(); i++)
            dims[i] = a.dim(i);
    }

    // FIXME move into narray-utils

    template<class T>
    void set_dims(colib::narray<T> &a, colib::intarray &dims) {
        switch(dims.length()) {
            case 0:
                a.dealloc();
                break;
            case 1:
                a.resize(dims[0]);
                break;
            case 2:
                a.resize(dims[0],dims[1]);
                break;
            case 3:
                a.resize(dims[0],dims[1],dims[2]);
                break;
            case 4:
                a.resize(dims[0],dims[1],dims[2],dims[3]);
                break;
            default:
                throw "bad rank";
        }
    }

    /// Extract the set of pixels with the given value and return it
    /// as a black-on-white image.
    inline void extract_segment(colib::bytearray &result,
                                colib::intarray &image,
                                int n) {
        makelike(result, image);
        fill(result, 255);
        for(int i = 0; i < image.length1d(); i++) {
            if(image.at1d(i) == n)
                result.at1d(i) = 0;
        }
    }

    // remove small connected components (really need to add more general marker code
    // to the library)
    template <class T>
    void remove_small_components(colib::narray<T> &bimage,int mw,int mh);
    template <class T>
    void remove_marginal_components(colib::narray<T> &bimage,int x0,int y0,int x1,int y1);

    /// Split a string into a list using the given array of delimiters.
    void split_string(colib::narray<colib::strbuf> &components,
                      const char *path,
                      const char *delimiters);
    void binarize_simple(colib::bytearray &result, colib::bytearray &image);
    void runlength_histogram(colib::floatarray &hist, colib::bytearray &img);
    int find_median(colib::floatarray &);
    void throw_fmt(const char *format, ...);
}

#endif
