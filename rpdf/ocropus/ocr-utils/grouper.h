// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// 
// You may not use this file except under the terms of the accompanying license.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you
// may not use this file except in compliance with the License. You may
// obtain a copy of the License at http:  www.apache.org/licenses/LICENSE-2.0
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
// Web Sites: www.iupr.org, www.dfki.de

#ifndef grouper_h__
#define grouper_h__

#include "colib.h"

namespace ocropus {

    // export to lua
    void sort_by_xcenter(colib::intarray &);

    struct IGrouper {
        int maxrange;
        int maxdist;
        // don't export this
        IGrouper() {
            maxrange = 4;
            maxdist = 2;
        }
        // resume export
        virtual void setSegmentation(colib::intarray &segmentation) = 0;
        virtual int length() = 0;
        virtual void getMask(colib::rectangle &r,colib::bytearray &mask,int index,int margin) = 0;
        virtual colib::rectangle boundingBox(int index) = 0;
        virtual void extract(colib::bytearray &out,colib::bytearray &mask,colib::bytearray &source,int index,int grow=0) = 0;
        virtual void extract(colib::floatarray &out,colib::bytearray &mask,colib::floatarray &source,int index,int grow=0) = 0;
        virtual void extract(colib::bytearray &out,colib::bytearray &source,colib::byte dflt,int index,int grow=0) = 0;
        virtual void extract(colib::floatarray &out,colib::floatarray &source,float dflt,int index,int grow=0) = 0;
        virtual void setClass(int index,int cls,float cost) = 0;
        virtual ~IGrouper() {}
    };

    IGrouper *make_StandardGrouper();
    // end export
}


#endif /* grouper_h__ */
