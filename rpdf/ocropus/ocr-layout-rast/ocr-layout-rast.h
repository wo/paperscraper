// -*- C++ -*-

// Copyright 2006-2008 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
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
// Project: OCRopus
// File: ocr-layout-rast.h
// Purpose: Extract textlines from a document image using RAST
//          For more information, please refer to the paper:
//          T. M. Breuel. "High Performance Document Layout Analysis",
//          Symposium on Document Image Understanding Technology, Maryland.
//          http://pubs.iupr.org/DATA/2003-breuel-sdiut.pdf
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_ocrlayoutrast__
#define h_ocrlayoutrast__

#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "iarith.h"
#include "heap.h"
#include "ocr-utils.h"

#include "ocr-char-stats.h"
#include "ocr-whitespace-cover.h"
#include "ocr-extract-gutters.h"
#include "ocr-ctextline-rast.h"


namespace ocropus {

    struct line{
        float c,m,d; // c is y-intercept, m is slope, d is the line of descenders
        float start,end,top,bottom; // start and end of line segment
        float istart,iend; //actual start and end of line segment in the image
        float xheight;

        line() {}
        line(TextLine &tl);
        TextLine getTextLine();
    };

    struct SegmentPageByRAST : colib::ISegmentPage {
        SegmentPageByRAST();
        ~SegmentPageByRAST() {}

        // Overlap threshold for grouping paragraphs into columns
        float column_threshold;

        int  id;
        colib::narray<int> val;
        colib::narray<int> ro_index;

        const char *description() {
            return "Segment page by RAST";
        }

        void init(const char **argv) {
            // nothing to be done
        }

        void rosort(colib::narray<TextLine> &textlines,
                    colib::rectarray &columns,
                    CharStats &charstats);

        void grouppara(colib::rectarray &paragraphs,
                       colib::narray<TextLine> &textlines,
                       CharStats &charstats);

        void getcol(colib::rectarray &columns,
                    colib::rectarray &paragraphs);


        void getcol(colib::rectarray &textcolumns,
                    colib::narray<TextLine> &textlines, 
                    colib::rectarray &gutters);

        void color(colib::intarray &image, colib::bytearray &in, 
                   colib::narray<TextLine> &textlines, 
                   colib::rectarray &columns);

    
        void segment(colib::intarray &image,colib::bytearray &in_not_inverted);
        void visualize(colib::intarray &result, colib::bytearray &in_not_inverted);

    private:
        void visualizeLayout(colib::intarray &result, colib::bytearray &in_not_inverted, colib::narray<TextLine> &textlines, colib::rectarray &columns,  CharStats &charstats);
        void segmentInternal(colib::intarray &visualization, colib::intarray &image,colib::bytearray &in_not_inverted, bool need_visualization);
        void visit(int k, colib::narray<bool> &lines_dag);
        void depth_first_search(colib::narray<bool> &lines_dag);


    };

    colib::ISegmentPage *make_SegmentPageByRAST();
    void visualize_segmentation_by_RAST(colib::intarray &result, colib::bytearray &in_not_inverted);
}

#endif
