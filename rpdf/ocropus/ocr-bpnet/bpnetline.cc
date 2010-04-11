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
// Project:  ocr-bpnet - neural network classifier
// File: bpnetline.cc
// Purpose: Bpnet line recognizer
// Responsible: Hagen Kaprykowsky
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include "ocrinterfaces.h"
#include "bpnet.h"
#include "bpnetline.h"
#include "grouping.h"
#include "segmentation.h"
#include "classify-chars.h"

using namespace colib;

namespace ocropus {
    IRecognizeLine *make_NewBpnetLineOCR(const char *path) {
        ICharacterClassifier *c = make_AdaptClassifier(make_BpnetClassifier());
        c->load(stdio(path, "rb"));
        return make_NewGroupingLineOCR(c, make_CurvedCutSegmenter());
    }
}
