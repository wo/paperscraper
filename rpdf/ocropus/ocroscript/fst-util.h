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

#ifndef fst_util_h__
#define fst_util_h__

#include "fst/lib/fst.h"
#include "fst/lib/fstlib.h"
#undef CHECK
#include "colib.h"
#include "fstutil.h"

fst::StdVectorFst *FstRead(const char *s) {
    return fst::StdVectorFst::Read(s);
}

void FstAddArc(fst::StdVectorFst *fst,int from,int ilabel,int olabel,float weight,int to) {
    CHECK_ARG(from >= 0 && from <= fst->NumStates());
    CHECK_ARG(ilabel > -(1<<30) && ilabel < (1<<30));
    ilabel &= 0x7fffffff;
    CHECK_ARG(olabel > -(1<<30) && olabel < (1<<30));
    olabel &= 0x7fffffff;
    CHECK_ARG(to >= 0 && to <= fst->NumStates());
    fst->AddArc(from,fst::StdArc(ilabel,olabel,weight,to));
}

void FstAddInputSymbol(fst::StdVectorFst *fst,const char *sym,int i) {
    fst->InputSymbols()->AddSymbol(sym,i);
}

void FstAddOutputSymbol(fst::StdVectorFst *fst,const char *sym,int i) {
    fst->OutputSymbols()->AddSymbol(sym,i);
}

void ArcSortInput(fst::StdVectorFst *fst) { ArcSort(fst,fst::StdILabelCompare()); }
void ArcSortOutput(fst::StdVectorFst *fst) { ArcSort(fst,fst::StdOLabelCompare()); }
void ProjectInput(fst::StdVectorFst *fst) { Project(fst,fst::PROJECT_INPUT); }
void ProjectOutput(fst::StdVectorFst *fst) { Project(fst,fst::PROJECT_OUTPUT); }
void ClosureStar(fst::StdVectorFst *fst) { Closure(fst,fst::CLOSURE_STAR); }
void ClosurePlus(fst::StdVectorFst *fst) { Closure(fst,fst::CLOSURE_PLUS); }
void EpsNormalizeInput(fst::StdVectorFst &a,fst::StdVectorFst *b) { EpsNormalize(a,b,fst::EPS_NORM_INPUT); }
void EpsNormalizeOutput(fst::StdVectorFst &a,fst::StdVectorFst *b) { EpsNormalize(a,b,fst::EPS_NORM_OUTPUT); }
void PushToInitial(fst::StdVectorFst &a,fst::StdVectorFst *b,bool weights,bool labels)
    { fst::Push<fst::StdArc,fst::REWEIGHT_TO_INITIAL>(a,b,(weights?fst::kPushWeights:0)|(labels?fst::kPushLabels:0)); }
void PushToFinal(fst::StdVectorFst &a,fst::StdVectorFst *b,bool weights,bool labels)
{ fst::Push<fst::StdArc,fst::REWEIGHT_TO_FINAL>(a,b,(weights?fst::kPushWeights:0)|(labels?fst::kPushLabels:0)); }

inline const char *bestpath(fst::StdVectorFst &fst) {
    colib::nustring a;
    ocropus::bestpath(a,fst);
    return a.mallocUtf8Encode();
}

#endif
