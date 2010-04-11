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
// Project: langmods
// File: langmod-aspell-stub.cc
// Purpose: stub to be compiled when aspell isn't there
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "langmod-dict.h"
#include "langmod-aspell.h"

using namespace colib;

namespace ocropus {
    param_string wordlist("wordlist", "/usr/share/dict/words",
                          "the list of words to use instead of aspell");

    IDict *make_Aspell() {
        try {
            return make_WordList(wordlist);
        } catch(const char *err) {
            fprintf(stderr,
                "There was an error while initializing a word list.\n");
            fprintf(stderr,
                "Try to set an environment variable `wordlist' to a UTF-8 encoded list of words.\n");
            fprintf(stderr,
                "(Right now, `wordlist' was set to %s)\n",
                 (const char *) wordlist);
            fprintf(stderr,
                "Maybe (release directory)/data/words/en-us will help.\n");
            fprintf(stderr,
                "Alternatively, you can install aspell libraries and recompile.\n");
            throw err;
        }
    }
}
