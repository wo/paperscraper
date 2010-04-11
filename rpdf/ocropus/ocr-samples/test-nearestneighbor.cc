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
// Project: roughocr -- mock OCR system exercising the interfaces and useful for testing
// File: test-nearestneighbor.cc
// Purpose: test nearest neighbor implementation
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "ocrcomponents.h"

using namespace colib;
using namespace ocropus;

int main(int argc,char **argv) {
    int ndim = 100;
    int ncls = 7;
    narray< narray<float> > vectors(1000);

    autodel<Classifier> nnbr;
    nnbr = make_KnnClassifier();
    nnbr->param("k",1);
    
    nnbr->start_training();
    for(int i=0;i<1000;i++) {
        floatarray v;
        make_random(vectors(i),ndim,1.0);
        nnbr->add(vectors(i),i%ncls);
    }
    nnbr->start_classifying();
    for(int i=0;i<1000;i++) {
        floatarray scores;
        nnbr->score(scores,vectors(i));
        int cls = argmax(scores);
        CHECK_CONDITION(cls==i%ncls);
    }
    for(int i=0;i<1000;i++) {
        floatarray scores;
        floatarray v;
        copy(v,vectors(i));
        perturb(v,0.00001);
        nnbr->score(scores,v);
        int cls = argmax(scores);
        CHECK_CONDITION(cls==i%ncls);
    }
}
