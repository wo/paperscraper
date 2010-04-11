#ifndef h_langmod_shortest_path__
#define h_langmod_shortest_path__

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
// File: language-models.h
// Purpose: interface for language-models.h
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de


namespace ocropus {    
    // FIXME this is obsolete
    struct IBestPath : virtual colib::IComponent {
        virtual void bestpath(colib::nustring &result,colib::floatarray &costs,colib::intarray &ids,colib::intarray &states) = 0;
    };


    /// This model searches for the shortest path from the 0-th node to the last,
    /// filling gaps. An arc i->j is permitted only when i < j. "Filling gaps"
    /// means that if there is no path to go from 0 to i then a zero-cost arc
    /// will be added from i-1 to i. That is done to overcome some defects
    /// in grouping.

    struct ISearchableFst : colib::IGenericFst, IBestPath {
    };

    ISearchableFst *make_ShortestPathSearchableFst();
};

#endif
