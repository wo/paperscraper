// -*- C++ -*-

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
// File: 
// Purpose: 
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#ifndef fstbuilder_h__
#define fstbuilder_h__

#undef CHECK
#include "fst/lib/fst.h"
#include "fst/lib/fstlib.h"
#undef CHECK
#include "colib.h"

namespace ocropus {
    struct FstBuilder : colib::IGenericFst {
        virtual fst::StdVectorFst *take() = 0;
    };
    FstBuilder *make_FstBuilder(fst::StdVectorFst *fst = NULL);
};

#endif /* fstbuilder_h__ */
