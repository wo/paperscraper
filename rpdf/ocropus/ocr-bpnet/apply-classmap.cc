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
    if(argc < 2) {
        fprintf(stderr,
                "usage: %s classmap <bytes >unicodes\n",
                argv[0]);
        exit(1);
    }
    const char *classmap_file = argv[1];
    ClassMap map;
    map.load(stdio(classmap_file, "r"));

    bytearray classes;
    bin_read(stdin, classes);
    nustring codes(classes.length());
    for(int i = 0; i < classes.length(); i++)
        codes[i] = nuchar(map.get_ascii(classes[i]));
    bin_write_nustring(stdout, codes);
}
