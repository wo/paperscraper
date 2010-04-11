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
// File: ocr-text-image-seg.h
// Purpose: Wrapper class for document zone classification.
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_ocrtextimageseg__
#define h_ocrtextimageseg__

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include "imgio.h"
#include "colib.h"
#include "ocr-utils.h" 

#include "ocr-classify-zones.h"
#include "ocr-pageseg-wcuts.h"

namespace ocropus {

    const int math_color     = 0x0001fa01;
    const int logo_color     = 0x0001fb01;
    const int text_color     = 0x00ff0101;
    const int table_color    = 0x0001fd01;
    const int drawing_color  = 0x0001fe01;
    const int halftone_color = 0x0001ff01;
    const int ruling_color   = 0x0001fc01;
    const int noise_color    = 0x00ffff00;

    // FIXME should also comply to ITextImageSegmentation
    struct TextImageSeg : colib::ICleanupBinary {
        ~TextImageSeg() {}
    
        const char *description() {
            return "Text/image segmentation to remove non-text zones \n";
        }

        void init(const char **argv) {
            // nothing to be done
        }

        void cleanup(colib::bytearray &out, colib::bytearray &in);

        void get_zone_classes(colib::narray<zone_class> &classes,
                              colib::rectarray &boxes,
                              colib::bytearray &image);

        int get_class_color(zone_class &zone_type);

        void remove_nontext_zones(colib::bytearray &out, colib::intarray &in);

        void remove_nontext_boxes(colib::rectarray &text_boxes,
                                  colib::rectarray &boxes,
                                  colib::bytearray &image);

        // Get text-image map from a segmented image
        void text_image_map(colib::intarray &out, colib::intarray &in);
        // Get text-image map from a binary image
        void text_image_map(colib::intarray &out, colib::bytearray &in);

    };

    colib::ICleanupBinary *make_TextImageSeg();
}

#endif
