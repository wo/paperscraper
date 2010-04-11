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

#ifndef h_ocroscript_util__
#define h_ocroscript_util__

#include "colib.h"
#include "imgio.h"
#include "imglib.h"
//#include "triv-hocr.h"
#include "ocr-layout-rast.h"
//#include "ocr-recognize-page.h"
#include "ocr-binarize-sauvola.h"
#include "langmod-aspell.h"
#include "langmod-shortest-path.h"
#include "segmentation.h"
#include "tesseract.h"
#include "ocr-utils.h"
#include "bpnet.h"
#include "ocrcomponents.h"
#ifdef HAVE_FST
#include "fstutil.h"
#endif

namespace ocropus {
    // print an array (for debugging)

    enum {pa_max = 20};

    template <class S>
    inline void debug_array(colib::narray<S> &a) {
        fprintf(stderr,"[n=%d min=%g max=%g] ",a.length1d(),double(min(a)),double(max(a)));
        if(a.rank()==1) {
            fprintf(stderr,"[%d] ",a.dim(0));
            int i;
            for(i=0;i<pa_max && i<a.length1d();i++)
                fprintf(stderr," %g",double(a.at1d(i)));
            if(i<a.length1d()) fprintf(stderr,"...");
            fprintf(stderr,"\n");
        } else if(a.rank()==2) {
            fprintf(stderr,"[%d %d]\n",a.dim(0),a.dim(1));
            int i;
            for(i=0;i<pa_max && i<a.dim(0);i++) {
                fprintf(stderr,"    <%d>",i);
                int j;
                for(j=0;j<pa_max && j<a.dim(1);j++)
                    fprintf(stderr," %g",double(a(i,j)));
                if(j<a.dim(1)) fprintf(stderr,"...");
                fprintf(stderr,"\n");
            }
            if(i<a.dim(0)) fprintf(stderr,"    ...\n");
        } else if(a.rank()==3) {
            fprintf(stderr,"[%d %d %d]",a.dim(0),a.dim(1),a.dim(2));
            int i;
            for(i=0;i<pa_max && i<a.length1d();i++)
                fprintf(stderr," %g",double(a.at1d(i)));
            if(i<a.length1d()) fprintf(stderr,"...");
            fprintf(stderr,"\n");
        } else if(a.rank()==4) {
            fprintf(stderr,"[%d %d %d %d]",a.dim(0),a.dim(1),a.dim(2),a.dim(3));
            int i;
            for(i=0;i<pa_max && i<a.length1d();i++)
                fprintf(stderr," %g",double(a.at1d(i)));
            if(i<a.length1d()) fprintf(stderr,"...");
            fprintf(stderr,"\n");
        } else {
            fprintf(stderr,"???\n");
        }
    }

}

inline colib::intarray *as_intarray(const char *a) {
    int n = strlen(a);
    colib::autodel<colib::intarray> result(new colib::intarray());
    for(int i=0;i<n;i++) result->push(a[i]);
    return result.move();
}

inline colib::intarray *as_intarray(colib::nustring &a) {
    colib::autodel<colib::intarray> result(new colib::intarray());
    for(int i=0;i<a.length();i++) result->push(a[i].value);
    return result.move();
}

inline colib::intarray *as_intarray(colib::bytearray &a) {
    colib::autodel<colib::intarray> result(new colib::intarray());
    for(int i=0;i<a.length();i++) result->push(a[i]);
    return result.move();
}

inline char *as_string(colib::bytearray &a) {
    char *result = (char *)malloc(a.length()+1);
    for(int i=0;i<a.length();i++) result[i] = a[i];
    result[a.length()] = 0;
    return result;
}

inline char *as_string(colib::nustring &a) {
    char *result = (char *)malloc(a.length()+1);
    for(int i=0;i<a.length();i++) result[i] = a[i].value;
    result[a.length()] = 0;
    return result;
}

inline char *as_string(colib::intarray &a) {
    char *result = (char *)malloc(a.length()+1);
    for(int i=0;i<a.length();i++) result[i] = a[i];
    result[a.length()] = 0;
    return result;
}

inline colib::intarray *utf32(const char *s) {
    colib::autodel<colib::intarray> result(new colib::intarray());
    utf8_decode(*result,s);
    return result.move();
}

inline const char *utf8(colib::intarray &a) {
    return malloc_utf8_encode(a);
}

#endif
