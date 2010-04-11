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
// Project: rbfn -- radial basis function network classifier
// File: confusion-matrix.h
// Purpose: class for a confusion matrix
// Responsible: Hagen Kaprykowsky (kapry@iupr.net)
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_confusionmatrix__
#define h_confusionmatrix__

#include <stdlib.h>


namespace iupr_bpnet {


    // class ConfusionMatrix
    // Keep track of a classifier's errors.
    class ConfusionMatrix
    {
    public:

        // constructor
        ConfusionMatrix(unsigned int nRows, unsigned int nCols) {
            confusion.resize(nRows,nCols);
            fill(confusion,0.0); 
        };

        // destructor
        ~ConfusionMatrix() {
            confusion.dealloc();
        };

        // set matrix entries to zero
        void clear() {
            fill(confusion,0.0);
        };

        // increment matrix entry by one
        void increment(int actual,int predicted) {
            if(actual>confusion.dim(0)) return;
            ASSERT(predicted<confusion.dim(1));
            confusion(actual,predicted)++;
        };

        // dump confusion matrix to stream.
        void print(FILE *stream) {
            for(int i=0;i<confusion.dim(0);i++) {
                for(int j=0;j<confusion.dim(1);j++) {
                    fprintf(stream, "cnf %2d %2d %6d\n",i,j,(int)(confusion(i,j)+0.1));
                }
            }
        }

    private:
        colib::floatarray confusion;
    };

    ConfusionMatrix *make_ConfusionMatrix(int ncls) {
        return new ConfusionMatrix(ncls,ncls);
    }



}
#endif
