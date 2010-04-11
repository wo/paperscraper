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
// Project: ocropus
// File: ocroscript.cc
// Purpose: scripting interface to OCRopus
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include <stdio.h>

static void complain() {
    fprintf(stderr, "\nOcroscript interactive mode not supported!\n\n");
    fprintf(stderr, "Please provide a lua script as single argument to run it!\n\n");
    //fprintf(stderr, "Since you don't have editline support compiled in, interactive mode won't work.\n");
    fprintf(stderr, "If you want to use ocroscript interactive mode, "
	    "please install\nlibedit-dev (or editline, ...), then "
	    "reconfigure and recompile.\n");
    throw "interactive mode not supported";
}

extern "C" char *readline(const char *) { complain(); return NULL; }
extern "C" void add_history(const char *) {  complain(); }
