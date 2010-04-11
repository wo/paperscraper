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
// File: lattice.cc
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org


#include "colib.h"
#include "lattice.h"
#include "beam-search.h"

using namespace colib;
using namespace ocropus;

namespace {
    struct Arc {
        int from;
        int to;
        int input;
        bool epsilon;
        float cost;
        int output;
    };
    

    struct StandardFst: IGenericFst {
        colib::objlist< colib::narray<Arc> > arcs_;
        colib::floatarray accept_costs;
        int start;
   
        virtual const char *description() {
            return "Lattice";
        }
     
        // reading
        virtual int nStates() {
            return arcs_.length();
        }
        virtual int getStart() {
            return start;
        }
        virtual float getAcceptCost(int node) {
            return accept_costs[node];
        }
        virtual void arcs(colib::intarray &ids,
                          colib::intarray &targets,
                          colib::intarray &outputs,
                          colib::floatarray &costs, 
                          int from) {
            colib::narray<Arc> &a = arcs_[from];
            makelike(ids, a);
            makelike(targets, a);
            makelike(outputs, a);
            makelike(costs, a);
            for(int i = 0; i < a.length(); i++) {
                ids[i]     = a[i].input;
                targets[i] = a[i].to;
                outputs[i] = a[i].epsilon ? 0 : a[i].output;
                costs[i]   = a[i].cost;
            }
        }
        virtual void clear() {
            arcs_.clear();
            accept_costs.clear();
            start = 0;
        }

        // writing
        virtual int newState() {
            arcs_.push();
            accept_costs.push(1e38);
            return arcs_.length() - 1;
        }
        virtual void addTransition(int from,int to,int output,float cost,int input) {
            Arc a;
            a.from = from;
            a.to = to;
            a.output = output;
            a.cost = cost;
            a.input = input;
            a.epsilon = output == 0;
            arcs_[from].push(a);
        }
        virtual void setStart(int node) {
            start = node;
        }
        virtual void setAccept(int node,float cost=0.0) {
            accept_costs[node] = cost;
        }
        virtual int special(const char *s) {
            return 0;
        }
        virtual void bestpath(colib::nustring &result) {
            beam_search(result, *this);
        }
    };

    
    struct CompositionFstImpl : CompositionFst {
        autodel<IGenericFst> l1, l2;
        int override_start;
        int override_finish;
        virtual const char *description() {return "CompositionLattice";}
        CompositionFstImpl(IGenericFst *l1, IGenericFst *l2,
                               int o_s, int o_f) :
            l1(l1), l2(l2), override_start(o_s), override_finish(o_f) {}

        IGenericFst *move1() {return l1.move();}
        IGenericFst *move2() {return l2.move();}

        virtual int nStates() {
            return l1->nStates() * l2->nStates();
        }
        int combine(int i1, int i2) {
            return i1 * l2->nStates() + i2;
        }
        virtual int getStart() {
            int s1 = override_start >= 0 ? override_start : l1->getStart();
            return combine(s1, l2->getStart());
        }
        virtual float getAcceptCost(int node) {
            int i1 = node / l2->nStates();
            int i2 = node % l2->nStates();
            double cost1;
            if(override_finish >= 0)
                cost1 = i1 == override_finish ? 0 : 1e38;
            else
                cost1 = l1->getAcceptCost(i1);
            return cost1 + l2->getAcceptCost(i2);
        }
        virtual void arcs(intarray &ids,
                          intarray &targets,
                          intarray &outputs,
                          floatarray &costs, 
                          int node) {
            int n1 = node / l2->nStates();
            int n2 = node % l2->nStates();
            intarray ids1, ids2;
            intarray t1, t2;
            intarray o1, o2;
            floatarray c1, c2;
            l1->arcs(ids1, t1, o1, c1, n1);
            l2->arcs(ids2, t2, o2, c2, n2);
            
            // sort & permute
            intarray p1, p2;

            quicksort(p1, o1);
            permute(ids1, p1);
            permute(t1, p1);
            permute(o1, p1);
            permute(c1, p1);
            
            quicksort(p2, o2);
            permute(ids2, p2);
            permute(t2, p2);
            permute(o2, p2);
            permute(c2, p2);

            int i1, i2;
            // l1 epsilon moves
            for(i1 = 0; i1 < o1.length() && !o1[i1]; i1++) {
                ids.push(ids1[i1]);
                targets.push(combine(t1[i1], n2));
                outputs.push(0);
                costs.push(c1[i1]);
            }
            // l2 epsilon moves
            for(i2 = 0; i2 < o2.length() && !o2[i2]; i2++) {
                ids.push(0);
                targets.push(combine(n1, t2[i2]));
                outputs.push(0);
                costs.push(c2[i2]);
            }
            // non-epsilon moves
            while(i1 < o1.length() && i2 < o2.length()) {
                while(i1 < o1.length() && o1[i1] < o2[i2]) i1++;
                if(i1 >= o1.length()) break;
                while(i2 < o2.length() && o1[i1] > o2[i2]) i2++;
                while(i1 < o1.length() && i2 < o2.length() && o1[i1] == o2[i2]){
                    for(int j = i2; j < o2.length() && o1[i1] == o2[j]; j++) {
                        ids.push(ids1[i1]);
                        targets.push(combine(t1[i1], t2[j]));
                        outputs.push(o1[i1]);
                        costs.push(c1[i1] + c2[j]);
                    }
                    i1++;
                }
            }
        }
    };
}

namespace ocropus {
    IGenericFst *make_StandardFst() {
        return new StandardFst();
    }
    CompositionFst *make_CompositionFst(IGenericFst *l1,
                                          IGenericFst *l2,
                                          int override_start,
                                          int override_finish) {
        return new CompositionFstImpl(l1, l2,
                                          override_start, override_finish);
    }
};
