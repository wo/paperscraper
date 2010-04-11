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

#ifndef fstutil_h__
#define fstutil_h__

#undef CHECK
#include "fst/lib/fst.h"
#include "fst/lib/fstlib.h"
#undef CHECK
#include "colib.h"
#include "lattice.h"

namespace ocropus {
    inline void check_valid_symbol(int symbol) {
        CHECK_ARG(symbol>0 && symbol<(1<<30));
    }

    struct Arcs {
        fst::StdVectorFst &fst;
	colib::autodel<fst::ArcIterator<fst::StdVectorFst> > arcs;
	int current_state;
	int current_arc;
	Arcs(fst::StdVectorFst &fst) : fst(fst) {
	    current_state = -1;
	    current_arc = -1;
	}
	int length() {
	    return fst.NumStates();
	}
	int narcs(int i) {
	    return fst.NumArcs(i);
	}
	const fst::StdArc &arc(int i,int j) {
	    seek(i,j);
	    return arcs->Value();
	}
    private:
	void seek(int i,int j) {
	    if(!arcs || i!=current_state) {
		arcs = new fst::ArcIterator<fst::StdVectorFst>(fst,i);
		current_arc = 0;
	    }
	    if(j==current_arc) {
		// do nothing
	    } if(current_arc<j+3) {
		while(current_arc<j) {
		    current_arc++;
		    arcs->Next();
		}
	    } else {
		arcs->Seek(j);
		current_arc = j;
	    }
	}
    };
    

    void fst_prune_arcs(fst::StdVectorFst &result,fst::StdVectorFst &fst,int maxarcs,float maxratio,bool keep_eps);


    double bestpath(colib::nustring &result, colib::floatarray &costs, colib::intarray &ids,fst::Fst<fst::StdArc> &fst,bool copy_eps=false);
    double bestpath(colib::nustring &result,fst::Fst<fst::StdArc> &fst,bool copy_eps=false);
    double bestpath2(colib::nustring &result, colib::floatarray &costs, colib::intarray &ids,fst::StdVectorFst &fst,fst::StdVectorFst &fst2,bool copy_eps=false);
    double bestpath2(colib::nustring &result,fst::StdVectorFst &fst,fst::StdVectorFst &fst2,bool copy_eps=false);

    fst::StdVectorFst *as_fst(const char *s,float cost=0.0,float skip_cost=9999,float junk_cost=9999);
    fst::StdVectorFst *as_fst(colib::intarray &a,float cost=0.0,float skip_cost=9999,float junk_cost=9999);
    fst::StdVectorFst *as_fst(colib::nustring &s,float cost=0.0,float skip_cost=9999,float junk_cost=9999);

    double score(fst::StdVectorFst &fst,colib::intarray &in);
    double score(fst::StdVectorFst &fst,const char *in);
    double score(colib::intarray &out,fst::StdVectorFst &fst,colib::intarray &in);
    double score(const char *out,fst::StdVectorFst &fst,const char *in);
    double translate(colib::intarray &out,fst::StdVectorFst &fst,colib::intarray &in);
    const char *translate(fst::StdVectorFst &fst,const char *in);
    double reverse_translate(colib::intarray &out,fst::StdVectorFst &fst,colib::intarray &in);
    const char *reverse_translate(fst::StdVectorFst &fst,const char *in);
    double sample(colib::intarray &out,fst::StdVectorFst &fst);

    double score(fst::StdVectorFst &fst,const char *s);
    const char *translate(fst::StdVectorFst &fst,colib::intarray &in);
    const char *reverse_translate(fst::StdVectorFst &fst,colib::intarray &in);

    fst::StdVectorFst *compose(fst::StdVectorFst &a,fst::StdVectorFst &b);
    fst::StdVectorFst *compose(fst::StdVectorFst &a,fst::StdVectorFst &b,bool rmeps,bool det,bool min);
    fst::StdVectorFst *determinize(fst::StdVectorFst &a);
    fst::StdVectorFst *difference(fst::StdVectorFst &a,fst::StdVectorFst &b);
    fst::StdVectorFst *intersect(fst::StdVectorFst &a,fst::StdVectorFst &b);
    fst::StdVectorFst *reverse(fst::StdVectorFst &a);

    void fst_add_ascii_symbols(fst::StdVectorFst &a,bool input,bool output);
    void fst_add_to_each_transition(fst::StdVectorFst &fst,int ilabel,int olabel,float cost,bool eps_too);
};

#endif /* fstbuilder_h__ */
