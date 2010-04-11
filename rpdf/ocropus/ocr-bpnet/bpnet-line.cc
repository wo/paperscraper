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
// File: bpnet-line.cc
// Purpose: ppnet line recognizer
// Responsible: Hagen Kaprykowsky
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include "colib.h"
#include "imgio.h"
#include "langmod-shortest-path.h"
#include "segmentation.h"
#include "ocr-utils.h"
#include "bpnetline.h"

using namespace ocropus;
using namespace imgio;
using namespace colib;

int main(int argc,char **argv) {

    try {
        if(argc!=3) throw "usage ... bpnet-file input.png";

        autodel<ISegmentLine> segmenter(make_CurvedCutSegmenter());
        autodel<IRecognizeLine> lineocr(make_NewBpnetLineOCR(argv[1]));
        autodel<ICharLattice> lattice(make_ShortestPathCharLattice());

        bytearray image;
        read_image_gray(image,argv[2]);
        make_page_black(image);

        intarray segmentation;
        segmenter->charseg(segmentation,image);

        idmap components;
        lineocr->recognizeLine(*lattice,components,segmentation,image);

        nustring result;
        lattice->bestpath(result);

        if(result.length()<1) {
            fprintf(stderr,"no result\n");
            return 1;
        } else {
            for(int i=0;i<result.length();i++)
                printf("%c",result[i].ord());
            printf("\n");
        }
    }
    catch(const char *oops) {
        fprintf(stderr,"oops: %s\n",oops);
    }
    return 0;
}

