// -*- C++ -*-

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
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#undef CHECK
#include "fst/lib/fst.h"
#include "fst/lib/fstlib.h"
#include "fst/lib/vector-fst.h"
#include "fst/lib/topsort.h"
#undef CHECK
#include "fstutil.h"
#include "colib.h"

#define EPSILON 0

namespace ocropus {
    using namespace fst;
    using namespace colib;

#if 1

    // Compute the best path through the given fst.

    double bestpath(nustring &result,floatarray &costs,intarray &ids,Fst<StdArc> &fst,bool copy_eps) {
        fst::Verify(fst);
        StdVectorFst shortest;
        ShortestPath(fst,&shortest,1);
        CHECK_ARG(shortest.NumStates() > 0);
        result.clear();
        costs.clear();
        ids.clear();
        int currentState = shortest.Start();
        for (int i=0; i < shortest.NumStates()-1; i++) {
            CHECK_ARG(shortest.NumArcs(currentState)==1);
            ArcIterator<StdVectorFst> aiter(shortest, currentState);
            const StdArc &arc = aiter.Value();
            if(arc.olabel!=EPSILON || copy_eps) {
                ids.push(arc.ilabel);
                result.push(nuchar(arc.olabel));
                costs.push(arc.weight.Value());
            }
            currentState = arc.nextstate;
        }
	return sum(costs);
    }

    // Compute the best path through the given fst.

    double bestpath(nustring &result,Fst<StdArc> &fst,bool copy_eps) {
        fst::Verify(fst);
        StdVectorFst shortest;
        ShortestPath(fst,&shortest,1);
        CHECK_ARG(shortest.NumStates() > 0);
        result.clear();
        int currentState = shortest.Start();
	double total = 0.0;
        for (int i=0; i < shortest.NumStates()-1; i++) {
            CHECK_ARG(shortest.NumArcs(currentState)==1);
            ArcIterator<StdVectorFst> aiter(shortest, currentState);
            const StdArc &arc = aiter.Value();
            if(arc.olabel!=EPSILON || copy_eps) {
                result.push(nuchar(arc.olabel));
                total += arc.weight.Value();
            }
            currentState = arc.nextstate;
        }
	return total;
    }

    // Compute the best path through the composition of the given fsts.

    double bestpath2(nustring &result,floatarray &costs,intarray &ids,StdVectorFst &fst,StdVectorFst &fst2,bool copy_eps) {
	
	ArcSort(&fst,StdOLabelCompare());
	ArcSort(&fst2,StdILabelCompare());
        ComposeFst<StdArc> composition(fst,fst2);
        return bestpath(result,costs,ids,composition,copy_eps);
    }

    // Compute the best path through the composition of the given fsts.

    double bestpath2(nustring &result,StdVectorFst &fst,StdVectorFst &fst2,bool copy_eps) {
	ArcSort(&fst,StdOLabelCompare());
	ArcSort(&fst2,StdILabelCompare());
        ComposeFst<StdArc> composition(fst,fst2);
        return bestpath(result,composition,copy_eps);
    }
#else

    // FIXME debug these and get them working; TopSort and sequential readout is the preferred way

    void bestpath(nustring &result, floatarray &costs, intarray &ids,StdVectorFst &fst) {
        fst::Verify(fst);
        StdVectorFst shortest;
        ShortestPath(fst,&shortest,1);
        fst::TopSort<StdArc>(&fst);
        CHECK_ARG(shortest.NumStates() > 0);
        result.resize(shortest.NumStates()-1); fill(result,nuchar('*'));
        costs.resize(shortest.NumStates()-1); fill(costs,999999);
        ids.resize(shortest.NumStates()-1); fill(ids,-1);
        int i=0;
        for (StateIterator<StdVectorFst> siter(fst); !siter.Done(); siter.Next(),i++) {
            StdArc::StateId state_id = siter.Value();
            ArcIterator<StdVectorFst> aiter(fst, state_id);
            const StdArc &arc = aiter.Value();
            ids[i] = arc.ilabel;
            result[i] = nuchar(arc.olabel);
            costs[i] = arc.weight.Value();
        }
    }

    void bestpath(nustring &result,StdVectorFst &fst) {
        fst::Verify(fst);
        StdVectorFst shortest;
        ShortestPath(fst,&shortest,1);
        fst::TopSort<StdArc>(&fst);
        CHECK_ARG(shortest.NumStates() > 0);
        result.resize(shortest.NumStates()-1); fill(result,nuchar('*'));
        int i = 0;
        for (StateIterator<StdVectorFst> siter(fst); !siter.Done(); siter.Next(),i++) {
            StdArc::StateId state_id = siter.Value();
            ArcIterator<StdVectorFst> aiter(fst, state_id);
            const StdArc &arc = aiter.Value();
            result[i] = nuchar(arc.olabel);
        }
    }
#endif

    // Convert a string to an fst.
    
    StdVectorFst *as_fst(intarray &a,float cost,float skip_cost,float junk_cost) {
        autodel<StdVectorFst> fst;
        fst = new StdVectorFst();
        int start = fst->AddState();
        fst->SetStart(start);
        int current = start;
        for(int i=0;i<a.length();i++) {
            int next = fst->AddState();
            check_valid_symbol(a[i]);
            fst->AddArc(current,StdArc(a[i],a[i],0.0,next));
	    if(skip_cost<1000)
		fst->AddArc(current,StdArc(EPSILON,a[i],skip_cost,next));
	    if(junk_cost<1000)
		fst->AddArc(current,StdArc(kSigmaLabel,EPSILON,junk_cost,current));
            current = next;
        }
        fst->SetFinal(current,cost);
        Verify(*fst);
        return fst.move();
    }

    // Convert a string to an fst.
    
    StdVectorFst *as_fst(const char *s,float cost,float skip_cost,float junk_cost) {
        intarray a;
        int n = strlen(s);
        for(int i=0;i<n;i++) a.push(s[i]);
        return as_fst(a,cost,skip_cost,junk_cost);
    }

    // Convert a string to an fst.
    
    StdVectorFst *as_fst(nustring &s,float cost,float skip_cost,float junk_cost) {
        intarray a;
        int n = s.length();
        for(int i=0;i<n;i++) a.push(s[i].value);
        return as_fst(a,cost,skip_cost,junk_cost);
    }
    
    // Score a string against an fst.
    
    double score(StdVectorFst &fst,intarray &in) {
	autodel<StdVectorFst> str(as_fst(in));
	autodel<StdVectorFst> result(compose(*str,fst));
	nustring out;
	floatarray costs;
	intarray ids;
	bestpath(out,costs,ids,*result,true);
	return sum(costs);
    }

    // Score a string against an fst.
    
    double score(StdVectorFst &fst,const char *s) {
	autodel<StdVectorFst> str(as_fst(s));
	autodel<StdVectorFst> result(compose(*str,fst));
	nustring out;
	floatarray costs;
	intarray ids;
	bestpath(out,costs,ids,*result,true);
	return sum(costs);
    }

    // Score a pair of strings against an fst.
    
    double score(intarray &out,StdVectorFst &fst,intarray &in) {
	autodel<StdVectorFst> in_fst(as_fst(in));
	autodel<StdVectorFst> out_fst(as_fst(out));
	autodel<StdVectorFst> left_fst(compose(*in_fst,fst));
	autodel<StdVectorFst> result(compose(*left_fst,*out_fst));
	nustring temp;
	floatarray costs;
	intarray ids;
	bestpath(temp,costs,ids,*result,true);
	return sum(costs);
    }

    // Score a pair of strings against an fst.
    
    double score(const char *out,StdVectorFst &fst,const char *in) {
	autodel<StdVectorFst> in_fst(as_fst(in));
	autodel<StdVectorFst> out_fst(as_fst(out));
	autodel<StdVectorFst> left_fst(compose(*in_fst,fst));
	autodel<StdVectorFst> result(compose(*left_fst,*out_fst));
	nustring temp;
	floatarray costs;
	intarray ids;
	bestpath(temp,costs,ids,*result,true);
	return sum(costs);
    }

    // Translate a string using an fst.

    double translate(intarray &out,StdVectorFst &fst,intarray &in) {
	autodel<StdVectorFst> str(as_fst(in));
	autodel<StdVectorFst> result(compose(*str,fst));
	nustring nout;
	floatarray costs;
	intarray ids;
	bestpath(nout,costs,ids,*result);
	out.clear();
	for(int i=0;i<nout.length();i++) out.push(nout(i).value);
	return sum(costs);
    }

    // Translate a string using an fst.

    const char *translate(StdVectorFst &fst,const char *in) {
	autodel<StdVectorFst> str(as_fst(in));
	autodel<StdVectorFst> result(compose(*str,fst));
	nustring nout;
	floatarray costs;
	intarray ids;
	bestpath(nout,costs,ids,*result);
	return nout.mallocUtf8Encode();
    }

    // Reverse translate a string using an fst.

    double reverse_translate(intarray &out,StdVectorFst &fst,intarray &in) {
	autodel<StdVectorFst> str(as_fst(in));
	autodel<StdVectorFst> result(compose(*str,fst));
	nustring nout;
	floatarray costs;
	bestpath(nout,costs,out,*result);
	return sum(costs);
    }

    // Reverse translate a string using an fst.

    const char *reverse_translate(StdVectorFst &fst,const char *in) {
	autodel<StdVectorFst> str(as_fst(in));
	autodel<StdVectorFst> result(compose(*str,fst));
	nustring nout;
	floatarray costs;
	intarray ids;
	bestpath(nout,costs,ids,*result);
	return malloc_utf8_encode(ids);
    }

    // Sample from an fst.

    double sample(intarray &out,StdVectorFst &fst) {
        // FIXME
        throw "unimplemented";
    }

    // Convenience compose function: perform eager composition after arc sorting.

    StdVectorFst *compose(StdVectorFst &a,StdVectorFst &b) {
	autodel<StdVectorFst> result(new StdVectorFst());
	ArcSort(&a,StdOLabelCompare());
	ArcSort(&b,StdILabelCompare());
	Compose(a,b,result.ptr());
	return result.move();
    }


    static StdVectorFst *fst_minimize(autodel<Fst<StdArc> > &composition,bool rmeps,bool det,bool min) {
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

    // Perform composition, then minimization.

    StdVectorFst *compose(StdVectorFst &a,StdVectorFst &b,bool rmeps,bool det,bool min) {
	ArcSort(&a,StdOLabelCompare());
	ArcSort(&b,StdILabelCompare());
        autodel<Fst<StdArc> > composition;
        composition = new ComposeFst<StdArc>(a,b);
	return fst_minimize(composition,rmeps,det,min);
    }

    // Convenience determinization function that returns the result.

    StdVectorFst *determinize(StdVectorFst &a) {
	autodel<StdVectorFst> result(new StdVectorFst());
	fst::Determinize(a,result.ptr());
	return result.move();
    }

    // Convenience difference function that returns the result.

    StdVectorFst *difference(StdVectorFst &a,StdVectorFst &b) {
	autodel<StdVectorFst> result(new StdVectorFst());
	fst::Difference(a,b,result.ptr());
	return result.move();
    }

    // Convenience intersection function that returns the result.

    StdVectorFst *intersect(StdVectorFst &a,StdVectorFst &b) {
	autodel<StdVectorFst> result(new StdVectorFst());
	fst::Intersect(a,b,result.ptr());
	return result.move();
    }

    // Convenience reverse function that returns the result.

    StdVectorFst *reverse(StdVectorFst &a) {
	autodel<StdVectorFst> result(new StdVectorFst());
	fst::Reverse(a,result.ptr());
	return result.move();
    }

    // Prune arcs between states.

    void fst_prune_arcs(StdVectorFst &result,StdVectorFst &fst,int maxarcs,float maxratio,bool keep_eps) {
	Arcs f(fst);
	CHECK_ARG(result.NumStates()==0);
	for(int i=0;i<fst.NumStates();i++) {
	    int state = result.AddState();
	    state = 0+state;
	    ASSERT(state==i);
	    result.SetFinal(i,fst.Final(i));
	}
	result.SetStart(fst.Start());
	for(int i=0;i<f.length();i++) {
	    // sort arcs by target, then weight
	    floatarray keys(f.narcs(i),2);
	    for(int j=0;j<f.narcs(i);j++) {
		keys(j,0) = f.arc(i,j).nextstate;
		keys(j,1) = f.arc(i,j).weight.Value();
	    }
	    intarray permutation;
	    rowsort(permutation,keys);
	    int current_to = -1;
	    int current_count = -1;
	    float current_top = -1;
	    for(int j=0;j<permutation.length();j++) {
		const StdArc &arc = f.arc(i,permutation[j]);
		int to = arc.nextstate;
		float weight = arc.weight.Value();
		if(to!=current_to) {
		    ASSERT(to>current_to);
		    current_to = to;
		    current_count = 0;
		    current_top = weight;
		}
		ASSERT(weight>=current_top);
		bool above_threshold = (current_count<maxarcs && weight-current_top<maxratio);
		bool has_eps = (arc.ilabel==0 || arc.olabel==0);
		if((keep_eps && has_eps) || above_threshold) {
		    result.AddArc(i,StdArc(arc.ilabel,arc.olabel,weight,to));
		    // count epsilons only if they are treated exceptionally
		    if(!(keep_eps && has_eps)) current_count++;
		}
	    }
	}
    }

    // Add an extra transition to each pair of states with a transition between them.
    // Optionally do this also for transitions between states that involve only epsilon labels.

    void fst_add_to_each_transition(StdVectorFst &fst,int ilabel,int olabel,float cost,bool eps_too) {
	Arcs f(fst);
	for(int i=0;i<f.length();i++) {
	    // sort arcs by target
	    intarray keys(f.narcs(i));
	    for(int j=0;j<f.narcs(i);j++) keys(j) = f.arc(i,j).nextstate;
	    intarray permutation;
	    quicksort(permutation,keys);
	    // now walk through and note the beginning of each new run of transitions
	    int current_to = -1;
	    for(int j=0;j<permutation.length();j++) {
		const StdArc &arc = f.arc(i,permutation[j]);
		int to = arc.nextstate;
		bool not_eps = (arc.ilabel!=0 && arc.olabel!=0);
		if(to!=current_to && (!not_eps || eps_too)) {
		    // in-place modification should be OK because these should get
		    // added at the end; note that we don't see the newly added arcs
		    fst.AddArc(i,StdArc(ilabel,olabel,cost,to));
		    current_to = to;
		}
	    }
	}
    }

    // Add an ASCII symbol table to the given fsts

    void fst_add_ascii_symbols(StdVectorFst &a,bool input,bool output) {
	autodel<SymbolTable> table(new SymbolTable("ASCII"));
	if(input && !a.InputSymbols()) a.SetInputSymbols(table.ptr());
	if(output && !a.OutputSymbols()) a.SetOutputSymbols(table.ptr());
	char buf[100];
	for(int i=0;i<=32;i++) {
	    if(i==0) {
		strcpy(buf,"EPSILON");
	    } else if(i==9) {
		strcpy(buf,"TAB");
	    } else if(i==10) {
		strcpy(buf,"NL");
	    } else if(i==13) {
		strcpy(buf,"CR");
	    } else if(i==32) {
		strcpy(buf,"SPACE");
	    } else {
		sprintf(buf,"%d.",i);
	    }
	    if(input) a.InputSymbols()->AddSymbol(buf,i);
	    if(output) a.OutputSymbols()->AddSymbol(buf,i);
	}
	for(int i=33;i<=126;i++) {
	    if(i=='"') {
		strcpy(buf,"''");
	    } else {
		buf[0] = i; buf[1] = 0;
	    }
	    if(input) a.InputSymbols()->AddSymbol(buf,i);
	    if(output) a.OutputSymbols()->AddSymbol(buf,i);
	}
	for(int i=127;i<256;i++) {
	    sprintf(buf,"%d.",i);
	    if(input) a.InputSymbols()->AddSymbol(buf,i);
	    if(output) a.OutputSymbols()->AddSymbol(buf,i);
	}
    }
}
