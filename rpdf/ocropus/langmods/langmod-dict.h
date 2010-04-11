// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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
// File: langmod-dict.h
// Purpose: dictionary-lookup based langmods
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de


#ifndef h_langmod_dict_
#define h_langmod_dict_

#include "ocrinterfaces.h"
#include "langmod-shortest-path.h"

namespace ocropus {

    struct IDict {
        /// look up a word and (if possible) correct it.
        /// Returns true if the word is in the dictionary
        /// (correction may be left empty in this case).
        /// Unsuccessful correction is indicated by leaving the output empty.
        virtual bool lookup(colib::nustring &correction,
                            colib::nustring &word) = 0;
        virtual ~IDict() {}
    };

    IDict *make_WordList(const char *path);
    IBestPath *make_DictBestPath(IBestPath *, IDict *);
};

#endif
