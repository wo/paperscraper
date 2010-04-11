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
// Project: ocr-utils
// File: feature-stream.cc
// Purpose: classmapped stream implementation
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de


#include "feature-stream.h"

using namespace colib;

namespace ocropus {

    struct ClassmappedStream : IFeatureStream {
        autodel<IFeatureStream> stream;
        ClassMap map;

        virtual int nsamples() {
            return stream->nsamples();
        }

        virtual bool read(floatarray &v, int &label) {
            bool result = stream->read(v, label);
            if(result)
                label = map.get_class(label);
            return result;
        }

        virtual void write(floatarray &v, int label) {
            label = map.get_ascii(label);
            stream->write(v, label);
        }

        ClassmappedStream(IFeatureStream *fs, ClassMap &cm) : stream(fs) {
            map.assign(cm);
        }

    };

    IFeatureStream *make_classmapped_stream(IFeatureStream *fs, ClassMap &cm) {
        return new ClassmappedStream(fs, cm);
    }

}
