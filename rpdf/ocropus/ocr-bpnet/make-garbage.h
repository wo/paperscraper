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
// Project: ocr-bpnet - neural network classifier
// File: make-garbage.h
// Purpose: producing garbage (wrongly segmented) characters from ground truth
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_make_garbage_
#define h_make_garbage_

#include "colib.h"

namespace ocropus {
    void make_garbage(colib::narray<colib::rectangle> &out_bboxes,
                      colib::narray<colib::bytearray> &out_garbage,
                      colib::intarray &in_segmented_line,
                      colib::ISegmentLine &segmenter);

    void make_garbage(colib::narray<colib::rectangle> &out_bboxes,
                      colib::narray<colib::bytearray> &out_garbage,
                      colib::intarray &in_segmented_line);
}

#endif
