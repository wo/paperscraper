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
// Project: bpnet -- neural network classifier
// File: ocr-train-bpnet.cc
// Purpose: training of a neural net
// Responsible: Hagen Kaprykowsky (kapry@iupr.net)
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de


#include "colib.h"
#include "charlib.h"

#include "colib.h"
#include "classmap.h"
#include "classify-chars.h"
#include "bpnet.h"

using namespace ocropus;
using namespace colib;

// for seeing the possible parameters please set the shell variable verbose as
// follows: export verbose=1

namespace ocropus {
    param_string inputformat("inputformat", "grid", "format of input data "
    "(possibilities are: ocropus, grid, aligndata or aligndata_grid)");
    param_int nhidden("nhidden",100,"Number of hidden units");
    param_float learningrate("learningrate",0.05,"Learning rate");
    param_float testportion("testportion",0.1,"Test portion (range: 0.0-1.0)");
    param_int epochs("epochs",20,"Number of training epochs");
    param_bool normalize("normalize",true,"Normalization");
    param_bool shuffle("shuffle",true,"Shuffle");
    param_bool garbage("garbage",false,"Garbage");
    param_bool filedump("filedump",true,"Dump to file");
    param_string net("net",NULL,"Net for retraining");
}

void run(ICharacterClassifier &classifier, ICharacterLibrary &charlib) {
    for(int i = 0; i < charlib.sectionsCount(); i++) {
        charlib.switchToSection(i);
        for(int j = 0; j < charlib.charactersCount(); j++) {
            classifier.set(charlib.character(j).image(),
                           charlib.character(j).baseline(),
                           charlib.character(j).xHeight(),
                           charlib.character(j).descender(),
                           charlib.character(j).ascender());
            nustring classification_result;
            classifier.best(classification_result);
            char buf[100];
            classification_result.utf8Encode(buf, sizeof(buf));
            fputs(buf, stdout);
        }
        putchar('\n');
    }
}

//#ifdef MAIN
int main(int argc,char **argv){

    try {
        if(!(argc==3 || argc==4)) {
            fprintf(stderr, "usage:... [path2grids/path2ocrodata/ path2filelist|path2filelist path2grids] output-file");
            exit(1);
        }

        autodel<ICharacterLibrary> charlib;
        // Character Library
        if(!strcasecmp(inputformat, "ocropus"))
            charlib = make_ocropus_charlib(argv[1]);
        else if(!strcasecmp(inputformat, "grid"))
            charlib = make_grid_charlib(argv[1],garbage);
        else if(!strcasecmp(inputformat, "aligndata"))
            charlib = make_SegmentationCharlib(argv[1]);
        /*else if(!strcasecmp(inputformat, "aligndata_grid")&&argc==4) {
        }*/
        else
            throw "unknown input format";

        // Classifier
        Classifier *c;
        if(filedump==true) {
            if(!strcasecmp(inputformat, "aligndata_grid")&&argc==4) {
                c = make_BpnetClassifierDumpIntoFile(argv[3]);
            } else {
                c = make_BpnetClassifierDumpIntoFile(argv[2]);
            }
        } else {
            c = make_BpnetClassifier();
        }

        c->param("nhidden",nhidden);
        c->param("epochs",epochs);
        c->param("learningrate",learningrate);
        c->param("testportion",testportion);
        c->param("normalize",normalize);
        c->param("shuffle",shuffle);
        c->param("filedump",filedump);

        // Character Classifier
        autodel<ICharacterClassifier> cc(make_AdaptClassifier(c));
        if(net) {
            cc->load(stdio(net, "r"));
        }
        /*if(!strcasecmp(inputformat, "aligndata_grid")&&argc==4) {
            train(*cc, argv[1], argv[2], garbage);
            cc->save(stdio(argv[3], "w"));
        } else */{
            train(*cc, *charlib);
            cc->save(stdio(argv[2], "w"));
        }
    }
    catch(const char *oops) {
        fprintf(stderr,"oops: %s\n",oops);
    }
    return 0;

}
//#endif
