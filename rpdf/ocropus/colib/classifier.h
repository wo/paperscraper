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
// Project: iupr common header files
// File: classifier.h
// Purpose: defines interfaces for classification and density estimation
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

/// \file classifier.h
/// \brief Interfaces for classification and density estimation

#ifndef h_classifier__
#define h_classifier__

#include <stdio.h>
#include "narray.h"
#include "smartptr.h"

namespace colib {
    class Classifier {
    public:
        virtual ~Classifier() {}
        virtual void param(const char *name,double value) = 0;
        virtual void add(floatarray &v,int c) = 0;
        virtual void score(floatarray &result,floatarray &v) = 0;
        virtual void start_training() = 0;
        virtual void start_classifying() = 0;
        virtual void seal() = 0;
        virtual void save(FILE *stream) = 0;
        virtual void load(FILE *stream) = 0;
        void save(const char *path) {
            save(stdio(path,"wb"));
        }
        void load(const char *path) {
            load(stdio(path,"rb"));
        }
    };

    class Density {
    public:
        virtual ~Density() {}
        virtual void param(const char *name,double value) = 0;
        virtual void add(floatarray &v) = 0;
        virtual double logp(floatarray &v) = 0;
        virtual void start_training() = 0;
        virtual void start_classifying() = 0;
        virtual void seal() = 0;
        virtual void save(FILE *stream) = 0;
        virtual void load(FILE *stream) = 0;
        void save(const char *path) {
            save(stdio(path,"wb"));
        }
        void load(const char *path) {
            load(stdio(path,"rb"));
        }
    };
}

#endif
