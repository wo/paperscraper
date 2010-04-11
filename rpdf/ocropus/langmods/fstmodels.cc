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
// Responsible: tmb
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include <stdio.h>
#include <float.h>
#include "fst/lib/fst.h"
#include "fst/lib/fstlib.h"
#undef CHECK
#include "colib.h"
#include "fstbuilder.h"
#include "fstutil.h"
#include "fstmodels.h"

#define EPSILON 0
#define STAR kSigmaLabel
#define REST kRhoLabel

using namespace fst;
using namespace colib;

namespace ocropus {

    // General purpose minimization function; this uses lazy versions
    // and then finally performs the minimization.
    
    static StdVectorFst *fst_minimize(autodel<StdVectorFst> &composition,bool rmeps,bool det,bool min) {
        autodel<Fst<StdArc> > epsfree;
        if(rmeps) epsfree = new RmEpsilonFst<StdArc>(*composition);
        else epsfree = composition.move();
        autodel<Fst<StdArc> > determinization;
	if(det) determinization = new DeterminizeFst<StdArc>(*epsfree);
        else determinization = epsfree.move();
	autodel<StdVectorFst> result(new StdVectorFst(*determinization));
        Minimize(result.ptr());
	return result.move();
    }

    // Create an fst that ignores the given set of symbols on its input.

    StdVectorFst *fst_ignoring(intarray &a,int maxsymbol,int minsymbol) {
	CHECK_ARG(minsymbol>0 && minsymbol<maxsymbol);
	CHECK_ARG(maxsymbol>0 && maxsymbol<10000000);
        autodel<StdVectorFst> fst;
        fst = new StdVectorFst();
        int start = fst->AddState();
        fst->SetStart(start);
        fst->SetFinal(start,0.0);
	narray<bool> used(maxsymbol);
	fill(used,0);
        for(int i=0;i<a.length();i++) {
            check_valid_symbol(a[i]);
	    used(a[i]) = 1;
            fst->AddArc(start,StdArc(a[i],EPSILON,0.0,start));
        }
        for(int i=minsymbol;i<used.length();i++) {
	    if(!used(i)) 
		fst->AddArc(start,StdArc(i,i,0.0,start));
        }
        Verify(*fst);
	return fst.move();
    }

    // Create an fst that keeps only the given set of symbols on its
    // input and deletes the rest.

    StdVectorFst *fst_keeping(intarray &a,int maxsymbol,int minsymbol) {
	CHECK_ARG(minsymbol>0 && minsymbol<maxsymbol);
	CHECK_ARG(maxsymbol>0 && maxsymbol<10000000);
        autodel<StdVectorFst> fst;
        fst = new StdVectorFst();
        int start = fst->AddState();
        fst->SetStart(start);
        fst->SetFinal(start,0.0);
	narray<bool> used(maxsymbol);
	fill(used,0);
        for(int i=0;i<a.length();i++) {
            check_valid_symbol(a[i]);
	    used(a[i]) = 1;
            fst->AddArc(start,StdArc(a[i],a[i],0.0,start));
        }
        for(int i=minsymbol;i<used.length();i++) {
	    if(!used(i)) 
		fst->AddArc(start,StdArc(i,EPSILON,0.0,start));
        }
        Verify(*fst);
	return fst.move();
    }

    // Create an fst that permits insertions and deletions of
    // arbitrary symbols with the given costs.

    StdVectorFst *fst_insdel(float ins,float del,int maxsymbol,int minsymbol) {
	CHECK_ARG(minsymbol>0 && minsymbol<maxsymbol);
	CHECK_ARG(maxsymbol>0 && maxsymbol<10000000);
        autodel<StdVectorFst> fst;
        fst = new StdVectorFst();
        int start = fst->AddState();
        fst->SetStart(start);
        fst->SetFinal(start,0.0);
        for(int i=minsymbol;i<maxsymbol;i++) {
            fst->AddArc(start,StdArc(i,i,0.0,start));
	    fst->AddArc(start,StdArc(EPSILON,i,ins,start));
	    fst->AddArc(start,StdArc(i,EPSILON,del,start));
        }
        Verify(*fst);
        return fst.move();
    }

    // Create an fst that permits limited insertions and deletions.

    StdVectorFst *fst_limited_edit_distance(int maxins,float ins,int maxdel,float del,int maxsymbol,int minsymbol) {
	CHECK_ARG(minsymbol>0 && minsymbol<maxsymbol);
	CHECK_ARG(maxsymbol>0 && maxsymbol<10000000);
	autodel<StdVectorFst> fst;
	fst = new StdVectorFst();
	int start = fst->AddState();
	fst->SetStart(start);
	fst->SetFinal(start,0.0);
	for(int r=minsymbol;r<maxsymbol;r++)
	    fst->AddArc(start,StdArc(r,r,0.0,start));
	int last = start;
	for(int i=0;i<maxins;i++) {
	    int current = fst->AddState();
	    // add the transition from the last state to the current;
	    // if the last state was the start state, make it a non-eps
	    // transition
	    for(int r=minsymbol;r<maxsymbol;r++)
		fst->AddArc(last,StdArc(i==0?r:EPSILON,r,ins,current));
	    // add the eps:a transition that returns to the start state
	    for(int r=minsymbol;r<maxsymbol;r++)
		fst->AddArc(current,StdArc(EPSILON,r,ins,start));
	    last = current;
	    current = fst->AddState();
	}
	last = start;
	for(int i=0;i<maxdel;i++) {
	    int current = fst->AddState();
	    // add the transition from the last state to the current;
	    // if the last state was the start state, make it a non-eps
	    // transition
	    for(int r=minsymbol;r<maxsymbol;r++)
		fst->AddArc(last,StdArc(r,i==0?r:EPSILON,del,current));
	    // add the eps:a transition that returns to the start state
	    for(int r=minsymbol;r<maxsymbol;r++)
		fst->AddArc(current,StdArc(r,EPSILON,del,start));
	    last = current;
	    current = fst->AddState();
	}
	Verify(*fst);
	return fst.move();
    }

    // Create an fst that corresponds to edit distance.

    StdVectorFst *fst_edit_distance(float subst,float ins,float del,int maxsymbol,int minsymbol) {
	CHECK_ARG(minsymbol>0 && minsymbol<maxsymbol);
	CHECK_ARG(maxsymbol>0 && maxsymbol<10000000);
	autodel<StdVectorFst> fst;
	fst = new StdVectorFst();
	int start = fst->AddState();
	fst->SetStart(start);
	fst->SetFinal(start,0.0);
	for(int i=minsymbol;i<maxsymbol;i++) {
	    for(int j=minsymbol;j<maxsymbol;j++) {
		float cost = (i==j)?0.0:subst;
		fst->AddArc(start,StdArc(i,j,cost,start));
	    }
	    fst->AddArc(start,StdArc(EPSILON,i,ins,start));
	    fst->AddArc(start,StdArc(i,EPSILON,del,start));
	}
	Verify(*fst);
	return fst.move();
    }

    // Create an fst that permits strings in the given size range.

    StdVectorFst *fst_size_range(int minsize,int maxsize,int maxsymbol,int minsymbol) {
	autodel<StdVectorFst> fst;
	fst = new StdVectorFst();
	int start = fst->AddState();
	fst->SetStart(start);
	int current = start;
	for(int i=0;i<maxsize;i++) {
	    if(i>=minsize) fst->SetFinal(current,0.0);
	    int next = fst->AddState();
	    for(int j=minsymbol;j<maxsymbol;j++) {
		fst->AddArc(current,StdArc(j,j,0.0,next));
	    }
	    current = next;
	}
	fst->SetFinal(current,0.0);
	return fst.move();
    }
    
    // Create a statistical unigram model.

    struct UnigramModelImpl : UnigramModel {
	int start;
	autodel<StdVectorFst> fst;
	UnigramModelImpl() {
	    clear();
	}
	void clear() {
	    fst = new StdVectorFst();
	    start = fst->AddState();
	    fst->SetStart(start);
	    fst->SetFinal(start,0.0);
	    Verify(*fst);
	}
	void addSymbol(int input,int output,float cost) {
	    check_valid_symbol(input);
	    check_valid_symbol(output);
	    fst->AddArc(start,StdArc(input,output,cost,start));
	}
	StdVectorFst *take() {
	    Verify(*fst);
	    return fst.move();
	}
    };
    UnigramModel *make_UnigramModel() {
	return new UnigramModelImpl();
    }

    // Create an fst corresponding to a dictionary.

    struct DictionaryModelImpl : DictionaryModel {
	int start;
	// FIXME change this to use the ICharLattice/IGenericFst interface
	autodel<StdVectorFst> fst;
	DictionaryModelImpl() {
	    clear();
	}
	void clear() {
	    fst = new StdVectorFst();
	    start = fst->AddState();
	    fst->SetStart(start);
	}
	void addWord(intarray &w,float cost) {
	    int n = w.length();
	    CHECK_ARG(n>0);
	    int current = start;
	    for(int i=0;i<n;i++) {
		float arc_cost = (i==0)?cost:0.0;
		int next = fst->AddState();
		fst->AddArc(current,StdArc(w[i],w[i],arc_cost,next));
		current = next;
	    }
	    fst->SetFinal(current,0.0);
	}
	void addWordSymbol(intarray &w,int output,float cost) {
	    int n = w.length();
	    CHECK_ARG(n>0);
	    int current = start;
	    for(int i=0;i<n;i++) {
		float arc_cost = (i==0)?cost:0.0;
		int next = fst->AddState();
		int output_symbol = (i==n-1)?output:EPSILON;
		fst->AddArc(current,StdArc(w[i],output_symbol,arc_cost,next));
		current = next;
	    }
	    fst->SetFinal(current,0.0);
	}
	void addWordTranscription(intarray &input,intarray &output,float cost) {
	    int n = input.length();
	    CHECK_ARG(n>0);
	    int current = start;
	    for(int i=0;i<n;i++) {
		float arc_cost = (i==0)?cost:0.0;
		int next = fst->AddState();
		int input_symbol = (i<input.length())?input[i]:EPSILON;
		int output_symbol = (i<output.length())?output[i]:EPSILON;
		fst->AddArc(current,StdArc(input_symbol,output_symbol,arc_cost,next));
		current = next;
	    }
	    fst->SetFinal(current,0.0);
	}
	// convenience methods for UTF8 input
	void addWord(const char *w,float cost=0.0) {
	    intarray a;
	    utf8_decode(a,w);
	    addWord(a,cost);
	}
	void addWordSymbol(const char *w,int output,float cost=0.0) {
	    intarray a;
	    utf8_decode(a,w);
	    for(int i=0;i<a.length();i++) if(a(i)==1) a(i) = 0;
	    addWordSymbol(a,output,cost);
	}
	void addWordTranscription(const char *input,const char *output,float cost=0.0) {
	    intarray a,b;
	    utf8_decode(a,input);
	    utf8_decode(b,output);
	    for(int i=0;i<a.length();i++) if(a(i)==1) a(i) = 0;
	    for(int i=0;i<a.length();i++) if(b(i)==1) b(i) = 0;
	    addWordTranscription(a,b,cost);
	}
	void minimize() {
	    Verify(*fst);
	    fst_minimize(fst,true,true,true);
	}
	StdVectorFst *take() {
	    Verify(*fst);
	    fst_minimize(fst,true,true,true);
	    return fst.move();
	}
    };
    DictionaryModel *make_DictionaryModel() {
	return new DictionaryModelImpl();
    }

    // Create an fst corresponding to an ngram.

    struct NgramModelImpl : NgramModel {
	int start;
	autodel<StdVectorFst> fst;
	intarray keys;
	floatarray costs;
	intarray states;
	bytearray done;
	// ngrams are in reading order, with the last element conditioned on the previous ones
	// use 0 for beginning and end of string
	void addNgram(intarray &ngram,float cost) {
	    intarray key;
	    reverse(key,ngram);
	    rowpush(keys,key);
	    costs.push(cost);
	}
	void addNgram(const char *ngram,float cost) {
	    intarray a;
	    utf8_decode(a,ngram);
	    for(int i=0;i<a.length();i++) if(a(i)==1) a(i) = 0;
	    addNgram(a,cost);
	}
	void construct() {
	    intarray perm;
	    rowsort(perm,keys);
	    rowpermute(keys,perm);
	    permute(costs,perm);
	    CHECK_ARG(rowduplicates(keys)==0);

	    fst = new StdVectorFst();
	    start = fst->AddState();
	    fst->SetStart(start);

	    states.resize(costs.length());
	    for(int i=0;i<states.length();i++)
		states(i) = fst->AddState();

	    int number_of_start_states = 0;
	    int number_of_final_states = 0;
	    for(int i=0;i<keys.dim(0);i++) {
		intarray prefix;
		rowcopy(prefix,keys,i);
		// final states "output" 0
		if(prefix(0)==0) {
		    fst->SetFinal(states(i),0.0);
		    number_of_final_states++;
		}
		remove_left(prefix,1);
		if(prefix(0)==0) {
		    // start states have no inputs other than 0
		    fst->AddArc(start,StdArc(EPSILON,EPSILON,0.0,states(i)));
		    // no further arcs going into this state
		    number_of_start_states++;
		    continue;
		}
		intarray matching;
		rowprefixselect(matching,keys,prefix);
		for(int j=0;j<matching.length();j++) {
		    int k = matching(j);
		    ASSERT(keys(k,0)==keys(i,1));
		    fst->AddArc(states(k),StdArc(keys(k,0),keys(k,0),costs(k),states(i)));
		}
	    }
	    // make sure we actually got start and final states; this doesn't guarantee
	    // connectivity, but it guards against the most common errors
	    ASSERTWARN(number_of_start_states>0);
	    ASSERTWARN(number_of_final_states>0);
	}
	StdVectorFst *take() {
	    construct();
	    Verify(*fst);
	    fst_minimize(fst,true,true,true);
	    return fst.move();
	}
	~NgramModelImpl() {}
    };
    NgramModel *make_NgramModel() {
	return new NgramModelImpl();
    }
}
