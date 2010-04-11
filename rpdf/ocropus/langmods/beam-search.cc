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
// File: beam-search.cc
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include "colib.h"
#include "beam-search.h"

using namespace colib;
using namespace ocropus;

namespace {
    struct Trail {
        intarray ids;
        intarray vertices;
        intarray outputs;
        floatarray costs;
        float total_cost;
        int vertex;
    };
    
    void copy(Trail &a, Trail &b) {
        copy(a.ids, b.ids);
        copy(a.vertices, b.vertices);
        copy(a.outputs, b.outputs);
        copy(a.costs, b.costs);
        a.total_cost = b.total_cost;
        a.vertex = b.vertex;
    }

    // Traverse the beam; accept costs are not traversed
    void radiate(narray<Trail> &new_beam,
                 narray<Trail> &beam,
                 IGenericFst &fst,
                 double bound,
                 int beam_width) {
        NBest nbest(beam_width); 
        intarray all_ids;
        intarray all_targets;
        intarray all_outputs;
        floatarray all_costs;
        intarray parents;
        
        for(int i = 0; i < beam.length(); i++) {
            intarray ids;
            intarray targets;
            intarray outputs;
            floatarray costs;
            fst.arcs(ids, targets, outputs, costs, beam[i].vertex);
            float max_acceptable_cost = bound - beam[i].total_cost;
            if(max_acceptable_cost < 0) continue;
            for(int j = 0; j < targets.length(); j++) {
                if(costs[j] >= max_acceptable_cost)
                    continue;
                nbest.add(all_targets.length(), -costs[j]-beam[i].total_cost);
                all_ids.push(ids[j]);
                all_targets.push(targets[j]);
                all_outputs.push(outputs[j]);
                all_costs.push(costs[j]);
                parents.push(i);
            }
        }

        // build new beam
        new_beam.resize(nbest.length());
        for(int i = 0; i < new_beam.length(); i++) {
            Trail &t = new_beam[i];
            int k = nbest[i];
            Trail &parent = beam[parents[k]];
            copy(t.ids, parent.ids);
            t.ids.push(all_ids[k]);
            copy(t.vertices, parent.vertices);
            t.vertices.push(beam[parents[k]].vertex);
            copy(t.outputs, parent.outputs);
            t.outputs.push(all_outputs[k]);
            copy(t.costs, parent.costs);
            t.costs.push(all_costs[k]);
            t.total_cost = -nbest.value(i);
            t.vertex = all_targets[k];
        }
    }

    void try_accepts(Trail &best_so_far,
                     narray<Trail> &beam,
                     IGenericFst &fst) {
        float best_cost = best_so_far.total_cost;
        for(int i = 0; i < beam.length(); i++) {
            float accept_cost = fst.getAcceptCost(beam[i].vertex);
            float candidate = beam[i].total_cost + accept_cost;
            if(candidate < best_cost) {
                copy(best_so_far, beam[i]);
                best_cost = best_so_far.total_cost = candidate;
            }
        }
    }
    
    void try_finish(Trail &best_so_far,
                     narray<Trail> &beam,
                     IGenericFst &fst,
                     int finish) {
        float best_cost = best_so_far.total_cost;
        for(int i = 0; i < beam.length(); i++) {
            if(beam[i].vertex != finish) continue;
            float candidate = beam[i].total_cost;
            if(candidate < best_cost) {
                copy(best_so_far, beam[i]);
                best_cost = best_so_far.total_cost = candidate;
            }
        }
    }
}


namespace ocropus {

    void beam_search(colib::intarray &ids,
                     colib::intarray &vertices,
                     colib::intarray &outputs,
                     colib::floatarray &costs,
                     IGenericFst &fst,
                     int beam_width,
                     int override_start,
                     int override_finish) {
        narray<Trail> beam(1);
        Trail &start = beam[0];
        start.total_cost = 0;
        if(override_start != -1)
            start.vertex = override_start;
        else
            start.vertex = fst.getStart();

        Trail best_so_far;
        best_so_far.vertex = start.vertex;
        best_so_far.total_cost = fst.getAcceptCost(start.vertex);

        while(beam.length()) {
            narray<Trail> new_beam;
            if(override_finish != -1)
                try_finish(best_so_far, beam, fst, override_finish);
            else
                try_accepts(best_so_far, beam, fst);
            double bound = best_so_far.total_cost;
            radiate(new_beam, beam, fst, bound, beam_width);
            move(beam, new_beam);
        }

        move(ids, best_so_far.ids);
        ids.push(0);
        move(vertices, best_so_far.vertices);
        vertices.push(best_so_far.vertex);
        move(outputs, best_so_far.outputs);
        outputs.push(0);
        move(costs, best_so_far.costs);
        costs.push(fst.getAcceptCost(best_so_far.vertex));
    }
    
    void beam_search(nustring &result,
                     colib::IGenericFst &fst,
                     int beam_width) {
        intarray ids;
        intarray vertices;
        intarray outputs;
        floatarray costs;
        beam_search(ids, vertices, outputs, costs, fst);
        for(int i = 0; i < outputs.length(); i++) {
            if(outputs[i])
                result.push(nuchar(outputs[i]));
        }
    }
}
