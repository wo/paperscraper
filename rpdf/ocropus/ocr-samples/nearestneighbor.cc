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
// File: nearestneighbor.cc
// Purpose: nearest neighbor classifier
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "kmeans.h"

using namespace ocropus;
using namespace colib;

namespace iupr_nearestneighbor {

    inline bool valid(floatarray &v) {
        for(int i=0;i<v.length1d();i++)
            if(isnan(v.at1d(i)))
                return 0;
        return 1;
    }

    class KnnClassifier : public Classifier {
    public:
        objlist<floatarray> vectors;
        narray<int> classes;
        int k;
        int ndim;
        int ncls;
        bool training;

        // from Classifier

        KnnClassifier() {
            training = true;
            ndim = -1;
            ncls = 0;
        }

        void param(const char *name,double value) {
            if(!strcmp(name,"k")) k = int(value);
            else throw "unknown parameter name";
        }

        void add(floatarray &v,int c) {
            CHECK_CONDITION(training);
            ASSERT(valid(v));

            if(ndim<0) ndim = v.dim(0); else CHECK_CONDITION(v.dim(0)==ndim);

            copy(vectors.push(),v);
            classes.push(c);
            ASSERT(vectors.length()==classes.length());
        }

        void start_training() {
            ncls = 0;
            training = true;
        }

        void start_classifying() {
            if(classes.length())
                ncls = classes[argmax(classes)]+1;
            else
                ncls = 0;
            training = false;
        }

        void seal() {
        }

        void score(floatarray &result,floatarray &v) {
            CHECK_CONDITION(!training);
            CHECK_CONDITION(v.dim(0)==ndim);
            NBest nbest(k);
            for(int i=0;i<vectors.length();i++) {
                nbest.add(i,-dist2squared(vectors[i],v));
            }
            result.resize(ncls);
            fill(result,0);
            for(int i=0;i<nbest.length();i++) {
                result(classes[nbest[i]])++;
            }
        }

        void save(FILE *stream) {
            fprintf(stream, "%d %d %d\n", k, ndim, vectors.length());
            for(int i=0;i<classes.length();i++)
                fprintf(stream, "%d\n", classes[i]);
            for(int i=0;i<vectors.length();i++)
                for(int j=0;j<vectors[i].length();j++)
                    fprintf(stream, "%g\n", vectors[i][j]);
        }

        void load(FILE *stream) {
            int n;
            fscanf(stream, "%d %d %d", &k, &ndim, &n);
            vectors.resize(n);
            classes.resize(n);
            for(int i=0;i<n;i++)
                fscanf(stream, "%d", &classes[i]);
            for(int i=0;i<n;i++) {
                vectors[i].resize(ndim);
                for(int j=0;j<vectors[i].length();j++)
                    fscanf(stream, "%f", &vectors[i][j]);
            }
        }
    };

    class KmeansClassifier : public Classifier {
    public:
        objlist<floatarray> vectors;
        narray<int> classes;
        narray<floatarray> clusters;
        narray<floatarray> values;
        int ndim;
        int ncls;
        int nclusters;
        int nrounds;
        int ntrials;
        bool training;

        // from Classifier

        KmeansClassifier() {
            training = true;
            ndim = -1;
            ncls = 2;
            nclusters = 50;
            nrounds = 10;
            ntrials = 10;
        }

        void param(const char *name,double value) {
            if(!strcmp(name,"nclusters")) nclusters = int(value);
            else if(!strcmp(name,"nrounds")) nrounds = int(value);
            else if(!strcmp(name,"ntrials")) ntrials = int(value);
            else throw "unknown parameter name";
        }

        void add(floatarray &v,int c) {
            CHECK_CONDITION(training);
            ASSERT(valid(v));

            if(ndim<0) ndim = v.dim(0); else CHECK_CONDITION(v.dim(0)==ndim);

            copy(vectors.push(),v);
            classes.push(c);
            ASSERT(vectors.length()==classes.length());
        }

        void start_training() {
            clusters.dealloc();
            values.dealloc();
            training = true;
        }

        void start_classifying() {
            training = false;
            int nvectors = vectors.length();
            int ncls = classes[argmax(classes)]+1;

            narray<floatarray> tvectors(vectors.length());
            for(int i=0;i<vectors.length();i++)
                move(tvectors(i),vectors[i]);
            kmeans(clusters,tvectors,nclusters,nrounds,ntrials);
            for(int i=0;i<vectors.length();i++)
                move(vectors[i],tvectors(i));

            for(int i=0;i<nclusters;i++) ASSERT(valid(clusters(i)));

            values.resize(nclusters);
            for(int i=0;i<nclusters;i++) {
                values(i).resize(ncls);
                fill(values(i),0);
            }

            for(int i=0;i<nvectors;i++) {
                int j = index(vectors[i]);
                values(j)(classes[i])++;
            }

            if(1) {
                for(int i=0;i<nclusters;i++) {
                    fprintf(stderr,"# values ");
                    for(int j=0;j<ncls;j++) {
                        fprintf(stderr," %8g",values(i)(j));
                    }
                    fprintf(stderr,"\n");
                }
            }
        }

        void seal() {
            vectors.dealloc();
            classes.dealloc();
        }

        int index(floatarray &v) {
            CHECK_CONDITION(!training);
            CHECK_CONDITION(v.dim(0)==ndim);
            narray<double> distances;
            for(int i=0;i<clusters.length1d();i++)
                distances.push(dist2squared(clusters.at1d(i),v));
            return argmin(distances);
        }

        void score(floatarray &result,floatarray &v) {
            CHECK_CONDITION(!training);
            CHECK_CONDITION(v.dim(0)==ndim);
            return copy(result,values(index(v)));
        }

        void save(FILE *stream) {
            throw "unimplemented";
        }

        void load(FILE *stream) {
            throw "unimplemented";
        }
    };
}

namespace ocropus {
    Classifier *make_KmeansClassifier() {
        using namespace iupr_nearestneighbor;
        return new KmeansClassifier();
    }
    Classifier *make_KnnClassifier() {
        using namespace iupr_nearestneighbor;
        return new KnnClassifier();
    }
};
