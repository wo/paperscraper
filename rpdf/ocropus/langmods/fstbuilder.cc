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
// Responsible: tmbdev
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include <stdio.h>
#include <float.h>
#include "fst/lib/fstlib.h"
#undef CHECK
#include "colib.h"
#include "fstbuilder.h"
#include "fstutil.h"

using namespace fst;
using namespace colib;
using namespace ocropus;

namespace {
    class FstBuilderImpl : public FstBuilder {
        autoref<StdVectorFst> fst;
        int nextstate;
        int maxstate;
    public:
        FstBuilderImpl(StdVectorFst *pFst) {
            clear();
            fst = pFst;
        }
        FstBuilderImpl() : fst() {
            clear();
        }
        const char *description() {
            return "FstBuilder";
        }
        void clear() {
            fst = 0;
            nextstate = 0;
            maxstate = 0;
        }
        int newState() {
            int result = fst->AddState();
            // Check that states are >=0 (we rely on that).
            CHECK_ARG(result>=0);
            // Check that states are assigned contiguously.
            // The library documentation seems to imply that they are.
            // Knowing this makes our assertions about states sharper.
            // Also, it is important for being able to use states as array indexes.
            CHECK_ARG(result==nextstate++);
            if(result>maxstate) maxstate = result;
            return result;
        }
        void addTransition(int from,int to,int output,float cost,int input) {
            CHECK_ARG(from>=0 && from<=maxstate);
            CHECK_ARG(to>=0 && to<=maxstate);
            CHECK_ARG(input>-(1<<30) && input<(1<<30));
            input &= 0x7fffffff;
            CHECK_ARG(output>-(1<<30) && output<(1<<30));
            CHECK_ARG(cost>-1e10 && cost<1e10 && cost==cost);
            output &= 0x7fffffff;
            // fprintf(stderr,"* from %d id %d c %d cost %f to %d\n",from,id,c.ord(),cost,to);
            fst->AddArc(from,StdArc(input,output,cost,to));
        }
        void setStart(int i) {
            CHECK_ARG(i>=0 && i<=maxstate);
            fst->SetStart(i);
        }
        void setAccept(int i,float f) {
            CHECK_ARG(i>=0 && i<=maxstate);
            fst->SetFinal(i,f);
        }
        int special(const char *s) {
            return 0;
        }
        void bestpath(nustring &result) {
            floatarray costs;
            intarray ids;
            ocropus::bestpath(result,costs,ids,*fst);
        }

        virtual int nStates() {
            return fst->NumStates();
        }
        virtual int getStart() {
            return fst->Start();
        }
        virtual float getAcceptCost(int node) {
            return fst->Final(node).Value();
        }
        virtual void arcs(colib::intarray &targets,
                          colib::intarray &outputs,
                          colib::floatarray &costs, 
                          int from) {
            int n = fst->NumArcs(from);
            targets.resize(n);
            outputs.resize(n);
            costs.resize(n);
            int i = 0;
            for(fst::ArcIterator<fst::StdFst> aiter(*fst, from);
                    !aiter.Done();
                    aiter.Next(), i++) {
                const fst::StdArc &arc = aiter.Value();
                targets[i] = arc.nextstate;
                outputs[i] = arc.olabel;
                costs[i] = arc.weight.Value();
            }
        }

        StdVectorFst *take() {
            // if(!Verify(*fst)) throw "bad fst or bug in fst library";
            return fst.move();
        }
    };
}

namespace ocropus {
    FstBuilder *make_FstBuilder(StdVectorFst *pFst) {
        if(pFst)
            return new FstBuilderImpl(pFst);
        else 
            return new FstBuilderImpl();
    }
} //namespace
