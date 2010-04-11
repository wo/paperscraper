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
// Project: bpnet -- Neural Network Classifier
// File: bpnet.h
// Purpose: Neural network classifier
// Responsible: Hagen Kaprykowsky (kapry@iupr.net)
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

/// \file bpnet.h
/// \brief Neural network classifier

#ifndef h_bpnet_
#define h_bpnet_

#include "colib.h"

namespace ocropus {
    /// Create a bpnet (standard backpropagation MLP) classifier.
    colib::Classifier *make_BpnetClassifier();

    colib::Classifier *make_BpnetClassifierDumpIntoFile(const char *path);
};
#endif
