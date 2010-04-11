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
// Project: iupr common header files
// File: ocrinterfaces.h
// Purpose: interfaces to OCR system components
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "quicksort.h"
#include "idmap.h"

using namespace colib;

namespace ocropus {

    void idmap::segments_of_id(intarray &result, int id) {
        CHECK_ARG(id >= 0);
        if(id >= segments.length())
            result.clear();
        else
            copy(result,*segments(id));
    }

    void idmap::ids_of_segment(intarray &result,int segment) {
        CHECK_ARG(segment >= 0);
        if(segment >= ids.length())
            result.clear();
        else
            copy(result,*ids(segment));
    }

    void idmap::associate(int id, int segment) {
        // FIXME ids should start with 1 -> CHECK_ARG(id>0) ?
        CHECK_ARG(id>=0 && id<100000);
        CHECK_ARG(segment>=0 && segment<100000);
        while(!(segment<ids.length())) ids.push();
        while(!(id<segments.length())) segments.push();
        if(first_index_of(*ids(segment),id)<0)
            ids(segment)->push(id);
        if(first_index_of(*segments(id),segment)<0)
            segments(id)->push(segment);
    }
        
    void idmap::clear() {
        ids.dealloc();
        segments.dealloc();
    }

    void idmap::segments_of_ids(colib::intarray &result, colib::intarray &ids) {
        intarray s;
        for(int i = 0; i < ids.length(); i++) {
            segments_of_id(s, ids[i]);
            for(int j = 0; j < s.length(); j++) result.push(s[j]);
        }
        quicksort(result);
    }
    void idmap::ids_of_segments(colib::intarray &result, colib::intarray &segs) {
        intarray s;
        for(int i = 0; i < segs.length(); i++) {
            segments_of_id(s, segs[i]);
            for(int j = 0; j < s.length(); j++) result.push(s[j]);
        }
        quicksort(result);
    }
};
