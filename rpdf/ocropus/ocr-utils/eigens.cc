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
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org


#include <math.h>
#include <iostream>
#include "colib.h"
#include "eigens.h"

using namespace colib;

namespace ocropus {

// Find a matrix of the form
//
// ( c s)
// (-s c)
//
// that, when applied to 
//
// (a x)
// (x b)
//
// from both sides (from the left, transposed), will suppress x.

static void find_jacobi_rotation_with_sqrt(double &c, double &s, double a, double b, double x) {
    // Let y = sc.
    // We have:
    //  (s+c)^2 = s^2+c^2+2sc = 1 + 2y
    //  (s-c)^2 = s^2+c^2-2sc = 1 - 2y
    //  (s^2-c^2)^2 = (1 + 2y)(1 - 2y) = 1 - 4y^2
    // 
    // Our equation looks like
    //  sc(a-b) = (s^2-c^2)x
    // Square both parts:
    //  y^2(a-b)^2 = (1-4y^2)x^2
    // Substituting z = y^2, we get
    //  ((a-b)^2 + 4x^2) z = x^2

    double x2 = x * x;
    double d = a - b;
    double d2 = d * d;
    double z = x2 / (d2 + 4 * x2);
    
    // so we have the sum of s^2 and c^2 (it's 1) and we have their product (z).
    // we can now simply solve the quadratic equation t^2-t+z=0
    double sqrtD = sqrt(.25 - z);

    // these can be chosen this way or vice versa - doesn't matter
    double s2 = .5 - sqrtD;
    double c2 = .5 + sqrtD;
    double abs_s = sqrt(s2);
    c = sqrt(c2);
    int s_sign = (d < 0) ^ (c2 < s2) ^ (x < 0);
    s = s_sign ? abs_s : -abs_s;
}

static void find_jacobi_rotation_with_atan(double &c, double &s, double a, double b, double x) {
    // we are solving sc(a-b)+(c^2-s^2)x = 0
    // let s = sin phi, c = cos phi
    // then sc = 1/2 sin(2 phi), c^2-s^2 = cos(2 phi)
    double tan_2_phi = x / (b - a);
    double phi = .5 * atan(tan_2_phi);
    s = sin(phi);
    c = cos(phi);
}

static void find_jacobi_rotation(double &c, double &s, double a, double b, double x) {
    // A little calculation (just matrix multiplication):
    //
    //         c     s
    //        -s     c
    // ___________________
    // a x | ac-xs  as+xc
    // x b | xc-bs  xs+bc 
    //     |
    // c -s|       c(as+xc)-s(xs+bc) = cs(a-b)+(c^2-s^2)x = 0
    // s  c|
    
    if (fabs(b - a) < 5 * fabs(x))
        find_jacobi_rotation_with_sqrt(c, s, a, b, x);
    else
        find_jacobi_rotation_with_atan(c, s, a, b, x);
}


static void rotate_rows(doublearray &psi, double c, double s, int p, int q)
{
    for(int i = 0; i < psi.dim(1); i++) {
        double x = psi(p,i);
        double y = psi(q,i);
        psi(p,i) = c * x - s * y;
        psi(q,i) = s * x + c * y;
    }
}

static void rotate_cols(doublearray &psi, double c, double s, int p, int q)
{
    for(int i = 0; i < psi.dim(0); i++) {
        double x = psi(i,p);
        double y = psi(i,q);
        psi(i,p) =  c * x - s * y;
        psi(i,q) =  s * x + c * y;
    }
}



static void cope_with_nonzero_element(doublearray &Q, doublearray &psi, int p, int q) {
    ASSERT(p != q);
    double c, s;
    find_jacobi_rotation(c, s, Q(p,p), Q(q,q), Q(p,q));
    rotate_rows(Q, c, s, p, q);
    rotate_cols(Q, c, s, p, q);
    rotate_rows(psi, c, s, p, q);
}


void jacobi_eigens(doublearray &Q, doublearray &psi, double epsilon, int max_iter) {
    ASSERT(Q.dim(0) == Q.dim(1));
    psi.resize(Q.dim(0), Q.dim(1));
    fill(psi, 0);
    for (int i = 0; i < psi.dim(0); i++)
        psi(i,i) = 1;
    for (int iter = 0; iter < max_iter; iter++) {
        double sum = 0;
        for (int i = 0; i < psi.dim(0); i++) for (int j = i + 1; j < psi.dim(1); j++)
            sum += fabs(Q(i, j));
        //fprintf(stderr, "jacobi: norm %g, epsilon %g\n", sum, epsilon);
        if (sum <= epsilon)
            break;
        for (int i = 0; i < psi.dim(0); i++) for (int j = i + 1; j < psi.dim(1); j++)
            cope_with_nonzero_element(Q, psi, i, j);
    }
}

}
