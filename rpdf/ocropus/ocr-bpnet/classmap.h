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
// Responsible: kapry
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_classmap_
#define h_classmap_

#include "colib.h"

namespace ocropus {

    /// ClassMap maps class labels to character codes.
    /// Character codes are named "ascii" here, but they're not limited to ASCII set.
    class ClassMap {
        colib::intarray classes;

        void skip_space(FILE *stream) {
            while(1) {
                int c = fgetc(stream);
                if (c != EOF && c != ' ' && c != '\n') {
                    ungetc(c, stream);
                    break;
                }
            }
        }

    public:
        /// Copies the given classmap into this one.
        void assign(ClassMap &m) {
            copy(classes, m.classes);
        }

        /// Get a corresponding class label or create a new one.
        int get_class(int ascii) {
            int n = classes.length();
            for(int i = 0; i < n; i++)
                if(classes[i] == ascii)
                    return i;
            classes.push(ascii);
            return n;
        }

        /// Get a corresponding class label or return -1 if class is not in the
        /// classmap. This is needed for retraining.
        int get_class_no_add(int ascii) {
            int n = classes.length();
            for(int i = 0; i < n; i++)
                if(classes[i] == ascii)
                    return i;
            return -1;
        }

        /// Get the current number of classes (might be increased later by get_class()).
        int length() {
            return classes.length();
        }

        /// Get the code of the character corresponding to the given class label.
        int get_ascii(int cls) {
            return classes[cls];
        }

        void load(FILE *stream) {
            int n;
            fscanf(stream, "%d", &n);
            classes.resize(n);
            for(int i = 0; i < n; i++) {
                fscanf(stream, "%x", &classes[i]);
            }
            skip_space(stream);
        }

        void save(FILE *stream) {
            int n = classes.length();
            fprintf(stream, "%d\n", n);
            for(int i = 0; i < n; i++)
                fprintf(stream, "%x\n", classes[i]);
        }
    };

}

#endif
