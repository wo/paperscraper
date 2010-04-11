// -*- C++ -*-

// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// Copyright 1995-2005 Thomas M. Breuel.
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
// Project: iupr common header files
// File: coords.h
// Purpose: points and rectangles with integer coordinates
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#ifndef fstmodels_h__
#define fstmodels_h__

namespace ocropus {
    fst::StdVectorFst *fst_ignoring(colib::intarray &a,int maxsymbol=128,int minsymbol=1);
    fst::StdVectorFst *fst_keeping(colib::intarray &a,int maxsymbol=128,int minsymbol=1);
    fst::StdVectorFst *fst_edit_distance(float subst,float ins,float del,int maxymbol=128,int minsymbol=1);
    fst::StdVectorFst *fst_limited_edit_distance(int maxins,float ins,int maxdel,float del,int maxsymbol=128,int minsymbol=1);
    fst::StdVectorFst *fst_insdel(float ins,float del,int maxymbol=128,int minsymbol=1);
    fst::StdVectorFst *fst_size_range(int minsize,int maxsize,int maxsymbol=128,int minsymbol=1);

    struct UnigramModel {
        virtual void clear() = 0;
        virtual void addSymbol(int input,int output,float cost=0.0) = 0;
        virtual fst::StdVectorFst *take() = 0;
        virtual ~UnigramModel() {}
    };
    UnigramModel *make_UnigramModel();

    struct DictionaryModel {
        virtual void clear() = 0;
        virtual void addWord(colib::intarray &w,float cost=0.0) = 0;
        virtual void addWordSymbol(colib::intarray &w,int output,float cost=0.0) = 0;
        virtual void addWordTranscription(colib::intarray &input,colib::intarray &output,float cost=0.0) = 0;
        virtual void addWord(const char *w,float cost=0.0) = 0;
        virtual void addWordSymbol(const char *w,int output,float cost=0.0) = 0;
        virtual void addWordTranscription(const char *input,const char *output,float cost=0.0) = 0;
        virtual void minimize() = 0;
        virtual fst::StdVectorFst *take() = 0;
        virtual ~DictionaryModel() {}
    };
    DictionaryModel *make_DictionaryModel();

    struct NgramModel {
        // ngrams are in reading order, with the last element conditioned on the previous ones
        virtual void addNgram(colib::intarray &ngram,float cost) = 0;
        virtual void addNgram(const char *ngram,float cost) = 0;
        virtual fst::StdVectorFst *take() = 0;
        virtual ~NgramModel() {}
    };
    NgramModel *make_NgramModel();
}

#endif /* fstmodels_h__ */
