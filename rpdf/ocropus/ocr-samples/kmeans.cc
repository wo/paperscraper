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
// Project: roughocr -- mock OCR system exercising the interfaces and useful for testing
// File: kmeans.cc
// Purpose: kmeans implementation
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"

using namespace colib;

namespace ocropus {

    param_bool verbose_kmeans("verbose_kmeans",1,"output progress report during kmeans computations");

    double entropy(intarray &a) {
        double n = 0;
        for(int i=0;i<a.dim(0);i++) n += a(i);
        double result = 0.0;
        for(int i=0;i<a.dim(0);i++) {
            double p = max(1,a(i))/n;
            result += - p * log(p);
        }
        return result;
    }

    void kmeans(narray<floatarray> &result,narray<floatarray> &vectors,int k,int maxrounds=2,int maxtrials=2) {
        int nvectors = vectors.length();
        double result_score = 0;
        double means_score;
        narray< narray<int> > indexes;
        doublearray dists;
        intarray counts;
        narray<floatarray> means;

        for(int trial=0;trial<maxtrials;trial++) {
        
            // initialize the means to a random sample of slightly perturbed
            // training vectors
        
            means.resize(k);
            counts.resize(k);
            fill(counts,0);

            for(int round=0;round<maxrounds;round++) {
                indexes.resize(k);
                for(int i=0;i<k;i++) indexes(i).clear();

                // if we have computed counts on the last round, reassign vectors with small counts

                for(int i=0;i<counts.dim(0);i++) {
                    if(counts(i) <= nvectors * 0.1 / k) {
                        int pick = rand() % nvectors;
                        copy(means(i),vectors[pick]);
                        perturb(means(i),norm2(means(i))*0.01);
                    }
                }

                // for each training vector, find the closest means vector
                // and add the index of the training vector to the index list for the means vector
            
                indexes.resize(k);
                dists.resize(k);
                for(int vi=0;vi<nvectors;vi++) {
                    for(int i=0;i<k;i++)
                        dists(i) = dist2squared(vectors[vi],means(i));
                    int minindex = argmin(dists);
                    indexes(minindex).push(vi);
                }

                // compute the mean of all the training vectors assigned to a means vector
            
                for(int i=0;i<k;i++) {
                    fill(means(i),0);
                    int nindexes = indexes(i).length();
                    if(nindexes==0) {
                        // just leave it alone
                    } else {
                        for(int j=0;j<nindexes;j++)
                            colib::add(means(i),vectors[indexes(i)[j]]);
                        int ndim = means(i).dim(0);
                        for(int j=0;j<ndim;j++)
                            means(i)(j) /= nindexes;
                    }
                }

                // compute the score of this choice of means

                counts.resize(indexes.dim(0));
                for(int i=0;i<indexes.dim(0);i++)
                    counts(i) = indexes(i).length();
                means_score = entropy(counts);

                // report progress if desired
            
                if(verbose_kmeans) {
                    fprintf(stderr,"# kmeans %2d %2d: ",trial,round);
                    fprintf(stderr," %8f",means_score);
                    for(int i=0;i<counts.dim(0);i++)
                        fprintf(stderr,"%5d",counts(i));
                    fprintf(stderr,"\n");
                }

                // copy the best result so far

                if(trial == 0 && round == 0 || means_score > result_score) {
                    result.resize(k);
                    for(int i=0;i<k;i++) copy(result(i),means(i));
                    result_score = means_score;
                }
            }
        }
    }

}
