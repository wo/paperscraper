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
// File: lattice.h
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#ifndef h_lattice_
#define h_lattice_

#include "ocrinterfaces.h"
#include "beam-search.h"

namespace ocropus {
    struct ReadOnlyFst : colib::IGenericFst {
        int oops() { throw "this FST is read-only"; }
        virtual void clear() {oops();}
        virtual int newState() {return oops();}
        virtual void addTransition(int from,int to,int output,float cost,int input) {oops();}
        virtual void setStart(int node) { oops(); }
        virtual void setAccept(int node,float cost=0.0) { oops(); }
        virtual int special(const char *s) { return oops(); }
        virtual void bestpath(colib::nustring &result) {
            beam_search(result, *this);
        }
    };

    struct CompositionFst : ReadOnlyFst {
        /// Return the 1st FST, releasing the ownership.
        virtual colib::IGenericFst *move1() = 0;
        /// Return the 2nd FST, releasing the ownership.
        virtual colib::IGenericFst *move2() = 0;
    };

    /// Make an unoptimized composition of two FSTs.
    /// The ids are always taken from the first FST only.
    /// Additional parameters, override_start and override_finish
    /// are indices into the first FST.
    /// 
    /// Setting override_start to nonnegative value has the same effect
    /// as l1->getStart() returning override_start.
    ///
    /// Setting override_finish to nonnegative value has the same effect
    /// as l2->getAcceptCost() returning 0 only for override_finish
    /// and INF otherwise.
    CompositionFst *make_CompositionFst(colib::IGenericFst *l1,
                                        colib::IGenericFst *l2,
                                        int override_start = -1,
                                        int override_finish = -1);

    /// Make a readable/writable FST (independent on OpenFST)
    /// with beam_search for bestpath().
    colib::IGenericFst *make_StandardFst();
};

#endif
