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
// File: ocr-char-stats.h
// Purpose: Header file declaring data structures for computing document
//          statistics
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_nucharstats__
#define h_nucharstats__

#include "colib.h"
#include "iarith.h"
#include "heap.h"

namespace ocropus {

    void sort_boxes_by_x0(colib::rectarray &boxes);    
    void sort_boxes_by_y0(colib::rectarray &boxes);
    int  calc_xheight(colib::rectarray &bboxes);

    //////////////////////////////////////////////////////////////////////////
    ///
    /// \struct CharStats
    /// Purpose: Character bounding boxes and statistics extracted from them
    ///
    //////////////////////////////////////////////////////////////////////////
    
    struct CharStats {
        int    img_height;
        int    img_width;
        int    xheight;
        int    char_spacing;
        int    word_spacing;
        int    line_spacing;
        colib::rectarray concomps;
        colib::rectarray char_boxes;
        colib::rectarray dot_boxes;

        CharStats();
        CharStats(CharStats &c);
        ~CharStats();
        void print();
        void get_char_boxes(colib::rectarray &concomps);
        void calc_char_stats();
        void calc_char_stats(colib::rectarray &cboxes);
        void calc_char_stats_for_one_line();
        void calc_char_stats_for_one_line(colib::rectarray &cboxes);
    };
    CharStats *make_CharStats();
    CharStats *make_CharStats(CharStats &c);

}

#endif
