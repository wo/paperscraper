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
// File: feature-stream.h
// Purpose: feature stream interface
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_feature_stream_
#define h_feature_stream_

#include "colib.h"
#include "classmap.h"

namespace ocropus {

    /// An IFeatureStream is a stream of multidimentional arrays.
    struct IFeatureStream {
        virtual int nsamples() = 0;

        /// Read an array and a label.
        /// The returned array may be multidimensional;
        /// sizes of different returned arrays may not be the same.
        /// \returns true if successful, false if EOF.
        virtual bool read(colib::floatarray &, int &label) = 0;

        /// Write an array and a label.
        /// Writing 1-dimensional arrays of equal length should be supported.
        /// Optionally,
        ///     writing multidimensional arrays may be permitted;
        ///     it may be permitted for different arrays to have different sizes.
        /// Not all formats support writing labels outside 0..255 range.
        /// Some formats will round up floats to the nearest integer
        /// (possibly even the nearest byte).
        ///
        virtual void write(colib::floatarray &, int label) = 0;

        virtual ~IFeatureStream() {}
    };

    /// Make a feature stream using a given classmap. The underlying feature stream
    /// stores character codes as labels, and the wrapper uses classes as labels.
    /// The classmap is copied.
    IFeatureStream *make_classmapped_stream(IFeatureStream *, ClassMap &);

    inline void copy(IFeatureStream &dst, IFeatureStream &src) {
        int label;
        colib::floatarray features;
        while(src.read(features, label)) {
            dst.write(features, label);
        }
    }

};

#endif
