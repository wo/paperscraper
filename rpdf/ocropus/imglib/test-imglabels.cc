// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// Copyright 1995-2005 Thomas M. Breuel
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
// Project: imglib -- image processing library
// File: test-imglabels.cc
// Purpose: test code for imglabels
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "imgio.h"
#include "imglib.h"


using namespace imglib;
using namespace colib;

int main(int argc,char **argv) {
    intarray image(512,512);
    fill(image,0);
    // we start count at 1 because label_components 
    // counts the background as well
    int count = 1;
    for(int i=10;i<500;i+=10) for(int j=10;j<500;j+=10) {
        image(i,j) = 1;
        count++;
    }
    int n = label_components(image);
    TEST_OR_DIE(n==count);
    TEST_OR_DIE(n==max(image)+1);
    // relabeling shouldn't change things
    n = label_components(image);
    TEST_OR_DIE(n==count);
    // recoloring shouldn't change the number of components
    simple_recolor(image);
    n = label_components(image);
    TEST_OR_DIE(n==count);
    narray<rectangle> boxes;
    bounding_boxes(boxes,image);
    TEST_OR_DIE(boxes.length()==count);
    // component 0 is the background
    TEST_OR_DIE(boxes[0].width()==image.dim(0));
    TEST_OR_DIE(boxes[0].height()==image.dim(1));
    // all other bounding boxes should be one pixel large
    for(int i=1;i<boxes.length();i++) {
        TEST_OR_DIE(boxes[i].width()==1);
        TEST_OR_DIE(boxes[i].height()==1);
    }
}
