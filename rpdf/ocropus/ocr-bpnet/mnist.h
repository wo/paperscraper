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
// Project: ocr-utils
// File: mnist.h
// Purpose: reading/writing datasets through IFeatureStream in MNIST format
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

/// \file mnist.h
/// \brief Reading/writing in MNIST format

#ifndef h_mnist_
#define h_mnist_

#include "feature-stream.h"

namespace ocropus {
    /// \brief Make a MNIST-format reading stream from a pair of files.
    /// The dataset is not entirely read into memory,
    /// so it's OK to read large datasets.
    ///
    /// \param prefix Path to the dataset excluding `-images-idx3-ubyte'
    ///               and `-labels-idx1-ubyte' suffixes.
    ///               For MNIST, the prefix might be `train' and `t10k',
    ///               possibly with directory prepended.
    IFeatureStream *make_MnistReader(const char *prefix,
                                     bool search_in_data_dir = false);
    
    /// \brief Make a MNIST-format writing stream.
    /// \param prefix cf. make_MnistReader().
    IFeatureStream *make_MnistWriter(const char *prefix);

    /// \brief Read MNIST training data from the standard location.
    /// (which is <ocropus share dir>/mnist/train-*)
    void MNIST_60K(colib::bytearray &images, colib::intarray &labels);
    
    /// \brief Read MNIST training data from the standard location.
    /// (which is <ocropus share dir>/mnist/test-*)
    void MNIST_10K(colib::bytearray &images, colib::intarray &labels);
};

#endif
