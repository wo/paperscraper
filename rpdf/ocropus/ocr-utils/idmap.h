// Copyright 2006-2008 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
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
// Project: ocr-utils
// File: idmap.h
// Purpose:
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

/// \file idmap.h
/// \brief ID map - a small class to keep track of segments and transition IDs

#ifndef h_idmap_
#define h_idmap_

#include <stdlib.h>
#include "narray.h"
#include "narray-util.h"
#include "smartptr.h"
#include "misc.h"
#include "coords.h"
#include "nustring.h"

namespace ocropus {
    /// \brief An idmap keeps track of segments and transition IDs.
    /// It is a many-to-many relationship between (arc) ids and segment indices.
    class idmap {
        colib::narray< colib::autoref<colib::intarray> > ids;
        colib::narray< colib::autoref<colib::intarray> > segments;
    public:
        /// Get the list of all segments corresponding to this transition ID.
        void segments_of_id(colib::intarray &result, int id);
        /// Get the list of all transition IDs corresponding to this segment.
        void ids_of_segment(colib::intarray &result,int segment);
        /// Get the list of segments corresponding to at least one of the IDs.
        void segments_of_ids(colib::intarray &result, colib::intarray &ids);
        /// Get the list of IDs corresponding to at least one of the segments.
        void ids_of_segments(colib::intarray &result, colib::intarray &segs);
        /// Remember the correspondence between the ID and the segment.
        void associate(int id, int segment);
        /// Clear all associations.
        void clear();
    };
}

#endif
