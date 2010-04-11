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
// File: 
// Purpose: 
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "grouper.h"
#include "dgraphics.h"
#include "ocr-utils.h"
#include "ocr-segmentations.h"
#include "segmentation.h"

using namespace imgio;
using namespace imglib;
using namespace colib;

namespace ocropus {

    struct GLineRec : IRecognizeLine {
        autodel<ISegmentLine> segmenter;
        const char *description() {
            return "GLineRec";
        }
        GLineRec() : segmenter(make_CurvedCutSegmenter()) {            
        }
        void recognizeLine(IGenericFst &result,bytearray &image) {
            make_page_black(image);
            bytearray binarized;
            binarize_simple(binarized, image);
            intarray segmentation;
            segmenter->charseg(segmentation, binarized);
            dshow(image);
            dwait();
            make_line_segmentation_black(segmentation);
            renumber_labels(segmentation,1);
            autodel<IGrouper> grouper(make_StandardGrouper());
            grouper->setSegmentation(segmentation);
            bytearray cimage,cmask;
            cmask.resize(10,10);
            fill(cmask,0);
            for(int i=0;i<grouper->length();i++) {
                // grouper->extract(cimage,cmask,image,i);
                grouper->extract(cimage,image,128,i);
                fprintf(stderr,"%d %d; %d %d\n",
                        cimage.dim(0),cimage.dim(1),min(cimage),max(cimage));
                dshow(cimage,"a");
                dshow(cmask,"b");
                dwait();
            }
        }
    };

    IRecognizeLine *make_GLineRec() {
        return new GLineRec();
    }
}
