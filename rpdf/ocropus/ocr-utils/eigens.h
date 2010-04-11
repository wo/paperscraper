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
// Project: 
// File: 
// Purpose: finding eigenvalues and eigenvectors
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

/// \file eigens.h
/// \brief Finding eigenvalues and eigenvectors

#ifndef h_eigens__
#define h_eigens__

#include "colib.h"

namespace ocropus {

    /// \brief Jacobi diagonalization.
    /// \param[in,out] Q    A symmetrical matrix. After the call,
    ///                     its diagonal will contain the eigenvalues
    ///                     of the original Q.
    /// \param[out] psi     Transposed eigenvector matrix
    ///                     (each row is an eigenvector)
    /// \param[in] epsilon  The sum of absolute values outside of the diagonal
    ///                     that we can tolerate.
    /// \param[in] max_iter The maximum number of iterations.
    ///                     Each iteration passes the whole triangle.
    void jacobi_eigens(colib::doublearray &Q, colib::doublearray &psi,
                       double epsilon = 0, int max_iter = 100);
};

#endif
