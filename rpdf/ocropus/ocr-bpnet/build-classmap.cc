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
// Project:
// File:
// Purpose:
// Responsible: kapry
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "classmap.h"
#include "narray-io.h"

using namespace ocropus;
using namespace colib;

int main(int argc, char **argv) {
    if(argc > 2 ||
       (argc == 2 && (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")))) {
        fprintf(stderr,
                "usage: %s [classmap(in-out)] <unicodes >bytes\n",
                argv[0]);
        exit(1);
    }

    ClassMap map;
    if(argc >= 2) {
        FILE *f = fopen(argv[1], "r");
        if(f) {
            fprintf(stderr, "loading classmap from %s\n", argv[1]);
            map.load(f);
            fclose(f);
        } else {
            fprintf(stderr, "creating a new classmap\n");
        }
    }

    nustring codes;
    bin_read_nustring(stdin, codes);
    bytearray classes;
    makelike(classes, codes);
    for(int i = 0; i < classes.length(); i++)
        classes[i] = map.get_class(codes[i].ord());
    bin_write_nustring(stdout, codes);

    if(argc >= 2)
        map.save(stdio(argv[1], "w"));
}

