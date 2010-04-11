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
// File: line-info.cc
// Purpose: getting line information from a single line
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include <stdlib.h>
#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "ocr-layout-rast.h"

using namespace imgio;
using namespace imglib;
using namespace colib;

namespace ocropus {

static bool internal_get_extended_line_info(float &intercept, float &slope,
                            float &xheight, float &descender_sink,
                            float &ascender_rise, intarray &charimage) {

    // Taken from Faisal's deskew-rast
    // Do connected component analysis
    make_page_binary_and_black(charimage);
    label_components(charimage,false);

    // Clean non-text and noisy boxes and get character statistics
    rectarray bboxes;
    bounding_boxes(bboxes,charimage);
    if(!bboxes.length())
        return false;
    autodel<CharStats> charstats(make_CharStats());
    charstats->get_char_boxes(bboxes);
    if(!charstats->char_boxes.length())
        return false;
    charstats->calc_char_stats();

    // Extract textlines
    autodel<CTextlineRAST> ctextline(make_CTextlineRAST());
    ctextline->min_q     = 2.0; // Minimum acceptable quality of a textline
    ctextline->min_count = 2;   // ---- number of characters in a textline
    ctextline->min_length= 30;  // ---- length in pixels of a textline
    narray<TextLine> textlines;
    ctextline->max_results=1;
    ctextline->min_gap = int(charstats->word_spacing*1.5);
    ctextline->extract(textlines,charstats);

    // Return the info
    if(!textlines.length()) {
        return false;
    }

    TextLine &t = textlines[0];
    intercept = t.c;
    slope = t.m;
    descender_sink = t.d;
    ascender_rise = t.d;
    xheight = t.xheight;
    return true;
}

bool get_extended_line_info(float &intercept, float &slope,
                            float &xheight, float &descender_sink,
                            float &ascender_rise, intarray &charimage) {
    
    intarray c;
    copy(c, charimage);
    return internal_get_extended_line_info(intercept, slope, xheight,
                                    descender_sink, ascender_rise, c);
}

bool get_extended_line_info_using_ccs(float &intercept, float &slope,
                                      float &xheight, float &descender_sink,
                                      float &ascender_rise, bytearray &charimage) {
    
    intarray c;
    copy(c, charimage);
    label_components(c);
    return internal_get_extended_line_info(intercept, slope, xheight,
                                           descender_sink, ascender_rise, c);
}

}
