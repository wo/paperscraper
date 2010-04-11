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
// File: ocr-extract-features.cc
// Purpose: command-line program that extracts features through interfaces
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include <sys/types.h>
#include <sys/stat.h>
#include "grid.h"
#include "charlib.h"
#include "extract-features.h"

using namespace ocropus;
using namespace colib;

static void append(bytearray &a, floatarray &b) {
    a.reserve(b.length());
    for(int i = 0; i < b.length(); i++)
        a.push((byte) b[i]);
}

static void show_usage_and_exit() {
    fprintf(stderr, "Usage: ocr-extract-features <input grid> <output pgm>\n");
    exit(1);
}

namespace ocropus {
    param_int use_garbage("use_garbage", 1, "whether to use garbage grids");
    param_int start("start", 0, "index of the first grid in a grid library");
    param_int finish("finish", 0, "index of the last grid in a grid library plus one (or 0 to disable)");
};

int main(int argc, char **argv) {
    if(argc < 3)
        show_usage_and_exit();

    struct stat st;
    stat(argv[1], &st);
    bytearray all_features;
    floatarray features;
    int count = 0;
    if (S_ISDIR(st.st_mode)) {
        autodel<ILineFeatureExtractor> e (make_LineFeatureExtractor());
        autodel<ICharacterLibrary> charlib(make_grid_charlib(argv[1], use_garbage));
        int section_cap = finish ? finish : charlib->sectionsCount();
        for(int section = start; section < section_cap; section++) {
            charlib->switchToSection(section);
            for(int i = 0; i < charlib->charactersCount(); i++) {
                ICharacter &c = charlib->character(i);
                e->extract(features, c.image(), c.baseline(), c.xHeight(), c.descender(), c.ascender());
                append(all_features, features);
                count++;
            }
        }
    } else {
        Grid g;
        g.load(argv[1]);

        if(g.hasLineInfo()) {
            autodel<ILineFeatureExtractor> e (make_LineFeatureExtractor());
            int baseline, xheight, descender, ascender;
            g.getLineInformation(baseline, xheight, descender, ascender);
            bytearray a;
            g.next(a); // skip line information
            while(g.next(a)) {
                e->extract(features, a, baseline, xheight, descender, ascender);
                append(all_features, features);
                count++;
            }
        } else {
            autodel<IFeatureExtractor> e(make_FeatureExtractor());
            bytearray a;
            while(g.next(a)) {
                e->extract(features, a);
                append(all_features, features);
                count++;
            }
        }
    }
    ASSERT(all_features.length() % count == 0);
    all_features.reshape(count, all_features.length() / count);
    write_pgm(argv[2], all_features);
}
