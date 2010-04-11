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
// File: test-idmap.cc
// Purpose: test cases for idmap implementation
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de



#include "colib.h"

using namespace colib;

bool has_repetitions(intarray &a) {
    intarray s;
    quicksort(s,a);
    for (int i = 1; i < s.length(); i++) {
        if (s[i] == s[i-1])
            return true;
    }
    return false;
}

int main() {
    idmap m;
    intarray a;

    // first, just some cheap poking
    //ASSERT(m.segments_count() == 0 && m.ids_count() == 0);
    m.associate(1,2);
    //ASSERT(m.segments_count() == 1 && m.ids_count() == 1);
    m.associate(1,3);
    m.associate(2,3);
    //ASSERT(m.segments_count() == 2 && m.ids_count() == 2);
    m.ids_of_segment(a, 3);
    ASSERT(a.length() == 2 && a[0] + a[1] == 3 && a[0] * a[1] == 2);

    // Now we'll get a 2d bool array and fill the idmap according to it.
    srand(0);
    enum {N=10};
    narray<bool> table(N, N);
    intarray xhist(N);
    intarray yhist(N);

    for(int count=0;count<10;count++) {
        m.clear();
        fill(xhist, 0);
        fill(yhist, 0);
        for(int x=0;x<N;x++) for (int y=0;y<N;y++) {
            table(x,y) = rand() % 2 != 0;
            if (table(x,y)) {
                m.associate(x,y);
                xhist[x]++;
                yhist[y]++;
            }
        }

        // For every column and row, check accordance with the table.

        for(int x=0;x<N;x++) {
            m.segments_of_id(a, x);
            ASSERT(!has_repetitions(a));
            ASSERT(a.length() == xhist[x]);
            for (int i = 0; i < a.length(); i++) {
                ASSERT(table(x,a[i]));
            }
        }
        
        for(int y=0;y<N;y++) {
            m.ids_of_segment(a, y);
            ASSERT(!has_repetitions(a));
            ASSERT(a.length() == yhist[y]);
            for (int i = 0; i < a.length(); i++) {
                ASSERT(table(a[i],y));
            }
        }
    }
}
