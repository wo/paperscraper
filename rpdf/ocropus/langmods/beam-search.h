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
// File: beam-search.h
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#ifndef h_beam_search_
#define h_beam_search_

#include "ocrinterfaces.h"

namespace ocropus {
    void beam_search(colib::intarray &ids,
                     colib::intarray &vertices,
                     colib::intarray &outputs,
                     colib::floatarray &costs,
                     colib::IGenericFst &fst,
                     int beam_width = 10,
                     int override_start = -1,
                     int override_finish = -1);


    void beam_search(colib::nustring &output,
                     colib::IGenericFst &fst,
                     int beam_width = 10);
}

#endif
