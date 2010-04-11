// -*- C++ -*-

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
// File: main-ocr-pageseg-xycut.cc
// Purpose: Page segmentation using XYCut algorithm
// Responsible: Joost van Beusekom (joost@iupr.net)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "ocr-pageseg-xycut.h"
#include "imgio.h"

using namespace ocropus;
using namespace imgio;
using namespace colib;

int main(int argc, char **argv){
    try {
        if(!(argc==3 || argc==2)) {
            fprintf(stderr, "Usage: ... input.png output.png\n");
            exit(1);
        }
        const char *outimage="out.png";
        if(argc==3){
            outimage=argv[2];
        }
        bytearray in ;
        intarray out;
        read_image_gray(in,stdio(argv[1],"r"));
        autodel<SegmentPageByXYCUTS> xycut(new SegmentPageByXYCUTS());
//         xycut->setParameters(0, 0, 50, 50) ;
        xycut->segment(out,in);
        write_png_rgb(stdio(outimage,"w"),out);
    }
    catch(const char *oops) {
        fprintf(stderr,"oops: %s\n",oops);
    }
    
}

