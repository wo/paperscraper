#ifndef h_classify_chars_
#define h_classify_chars_

// -*- C++ -*-

// Copyright 2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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

#include "colib.h"
#include "charlib.h"

namespace ocropus {

    colib::ICharacterClassifier *make_AdaptClassifier(
        colib::Classifier *,
        bool output_garbage = false);

    void train(colib::ICharacterClassifier &, ICharacterLibrary &);
/*    void train(colib::ICharacterClassifier &,
               const char *path_file_list_segmentation,
               const char *path_file_list_grid, 
               bool garbage = false);*/

}

#endif
