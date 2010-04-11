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
// File: test-process.cc
// Purpose: testing process.cc
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "process.h"
#include "colib.h"

using namespace ocropus;

int main() {
    // smoke test: put 2+2 to bc and grab 4.
    autodel<IProcess>  proc;
    proc = run_process("bc");
    fprintf(proc->into(), "2+2\n");
    char buf[1000];
    fgets(buf, sizeof(buf), proc->from());
    ASSERT(atoi(buf) == 4);
    proc->close();
}
