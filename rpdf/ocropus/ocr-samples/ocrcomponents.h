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
// Project: roughocr -- mock OCR system exercising the interfaces and useful for testing
// File: ocrcomponents.h
// Purpose: interface to constructors for various OCR components
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_ocrcomponents__
#define h_ocrcomponents__

#include "colib.h"

namespace ocropus {
    // export to lua
    colib::Classifier *make_KmeansClassifier();
    colib::Classifier *make_KnnClassifier();
    void binarize_by_range(colib::bytearray &image,float fraction=0.5);
    void binarize_by_range(colib::bytearray &out,colib::floatarray &in,float fraction=0.5);
    colib::IBinarize *make_BinarizeByRange();
    colib::ISegmentLine *make_SegmentLineByCCS();
    colib::ISegmentLine *make_SegmentLineByProjection();
    colib::ISegmentPage *make_SegmentPageBy1CP();
    colib::ISegmentPage *make_SegmentPageBySmear();
    //colib::ICharLattice *make_TrivialCharLattice();
    // end export
}

#endif
