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
// Project: ocr-adaptive
// File: shortest-path.cc
// Purpose: A language model that calculates shortest path (and fills in gaps)
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include <float.h>
#include "colib.h"
#include "langmod-shortest-path.h"

using namespace colib;
using namespace ocropus;

namespace {

    struct transition {
        int from;
        int to;
        int id;     
        int output; // by convention, -1 = epsilon
        float cost;
    };

    struct ShortestPath : ISearchableFst {
        objlist< narray<transition> > matrix;
        intarray previous;
        narray<transition> transitions;
        int path_length; // in transitions
        bool success;

        // set a state as an accept state
        virtual void setAccept(int node,float cost=0.0) {
            if(node != matrix.length() - 1 || cost != 0)
                throw "setAccept in ShortestPath is just a stub, OK?";
        }


        virtual const char *description() {
            return "ShortestPath";
        }
        
        virtual void init(const char **) {
        }
        
        virtual void start_context() {
        }

        virtual void clear() {
            matrix.clear();
        }

        virtual void start_chunk(int n) {
            matrix.resize(n);
            for(int i = 0; i < n; i++) {
                matrix[i].clear();
            }
        }

        virtual void add_transition(int from, int to, int output, float cost, int id) {
            while(from >= matrix.length()) matrix.push();
            while(to >= matrix.length()) matrix.push();
            CHECK_ARG(from < to);
            transition &t = matrix(from).push();
            t.from = from;
            t.to = to;
            t.id = id;
            t.output = output;
            t.cost = cost;
        }

        virtual void addTransition(int from,int to,int output,float cost,int input) {
            add_transition(from, to, output, cost, input);
        }

        virtual int newState() {
            matrix.push();
            return matrix.length() - 1;
        }

        // set the start state
        virtual void setStart(int node) {
            if(node)
                throw "setStart in ShortestPath is just a stub, OK?";
        }

        virtual int special(const char *s) {
            return 0;
        }

        virtual void compute(int n) {
            floatarray a(matrix.length()); // costs to get there
            fill(a, FLT_MAX);
            a(0) = 0;
            previous.resize(matrix.length());
            transitions.resize(matrix.length());

            // invariant: first i+1 items of `a' are filled with true costs
            // so a(i) is always the true cost
            for(int i = 0; i < matrix.length(); i++) {
                if(a[i] >= FLT_MAX) {
                    // we have a skip; remove it
                    // let j be the last accessible vertex
                    int j;
                    for(j = i - 1; j >= 0; j--) {
                        if (a[j] < FLT_MAX)
                            break;
                    }
                    // add zero-cost transition from j to i to fill the gap
                    transition &t = matrix(j).push();
                    t.from = j;
                    t.to = i;
                    t.id = -1;
                    t.output = -1; // recall that it means epsilon
                    t.cost = 0;
                    a[i] = a[j];
                    previous[i] = j;
                    transitions[i] = t;
                }
                narray<transition> &t = matrix[i];
                for(int j = 0; j < t.length(); j++) {
                    float new_cost = a[i] + t[j].cost;
                    int to = t[j].to;
                    CHECK_ARG(to < matrix.length());
                    if(new_cost < a[to]) {
                        a[to] = new_cost;
                        previous[to] = i;
                        transitions[to] = t[j];
                    }
                }
            }

            if(a(matrix.length() - 1) >= FLT_MAX) {
                success = false;
            } else {
                success = true;
                path_length = 0;
                int i = matrix.length() - 1;
                while(i) {
                    if (transitions[i].output != -1)
                        path_length++;
                    i = previous(i);
                }
            }
        }

        virtual int nresults() {
            return success ? 1 : 0;
        }

        virtual void nbest(nustring &result, floatarray &costs, intarray &ids, intarray &states, int index) {
            CHECK_ARG(index == 0);
            result.resize(path_length);
            costs.resize(path_length);
            ids.resize(path_length);
            states.resize(path_length);
            int i = matrix.length() - 1;
            int n = path_length - 1;
            while (i) {
                if(transitions[i].output == -1) {
                    i = previous(i);
                    continue;
                }
                result[n] = nuchar(transitions[i].output);
                costs[n] = transitions[i].cost;
                ids[n] = transitions[i].id;
                states[n] = i;
                n--;
                ASSERT(transitions[i].from == previous[i]);
                //printf("[%d] %d -> %d\n", transitions[i].id, transitions[i].from, transitions[i].to);
                i = previous(i);
            }
            ASSERT(n == -1);
        }

        virtual void bestpath(nustring &result, floatarray &costs, intarray &ids, intarray &states) {
            compute(1);
            nbest(result, costs, ids, states, 0);
        }
        virtual void bestpath(nustring &result) {
            floatarray costs;
            intarray ids, states;
            bestpath(result, costs, ids, states);
        }

    };
}

namespace ocropus {

    ISearchableFst *make_ShortestPathSearchableFst() {
        return new ShortestPath();
    }
}
