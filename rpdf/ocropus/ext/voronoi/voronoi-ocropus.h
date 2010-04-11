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
// File: voronoi-ocropus.h
// Purpose: Wrapper class for voronoi code
//
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de


#ifndef h_voronoi_ocropus__
#define h_voronoi_ocropus__

#include "colib.h"
#include "ocr-utils.h"

namespace ocropus {
    
    struct SegmentPageByVORONOI : colib::ISegmentPage {
    public:
        SegmentPageByVORONOI() {}
        ~SegmentPageByVORONOI() {}
            
        const char *description() {
            return "segment page by Voronoi algorithm\n";
        }
            
        void segment(colib::intarray &image,colib::bytearray &in);
    };

    colib::ISegmentPage *make_SegmentPageByVORONOI();

}


#endif
