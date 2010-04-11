// Copyright 2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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
// File: resource-path.cc
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include "resource-path.h"
#include "ocr-utils.h"

static const char *default_path = "/usr/local/share/ocropus:"
                                  "/usr/share/ocropus";

using namespace colib;


static strbuf original_path;
static narray<strbuf> path;
static strbuf errmsg;


namespace ocropus {

    void set_resource_path(const char *s) {
        const char *env = getenv("OCROPUS_DATA");
        strbuf p;
        if(!s && !env)
            p = default_path;
        else if(!s)
            p = env;
        else if(!env)
            p = s;
        else {
            p.ensure(strlen(s) + 1 + strlen(env));
            strcpy(p, s);
            strcat(p, ":");
            strcat(p, env);
        }
        original_path = p;
        split_string(path, p, ":;"); 
    }
    
    FILE *open_resource(const char *relative_path) {
        if(!original_path)
            set_resource_path(NULL);
        for(int i = 0; i < path.length(); i++) {
            strbuf s;
            s.ensure(strlen(path[i]) + 1 + strlen(relative_path));
            strcpy(s, path[i]);
            strcat(s, "/");
            strcat(s, relative_path);
            FILE *f = fopen(s, "rb");
            if(f)
                return f;
        }
        errmsg.ensure(strlen(original_path) + strlen(relative_path) + 1000);
        sprintf(errmsg, "Unable to find resourse %s in the data path, which is %s", (char *) relative_path, (char *) original_path);
        fprintf(stderr, "%s\n", (char *) errmsg);
        fprintf(stderr, "Please check that your $OCROPUS_DATA variable points to the OCRopus data directory");
        throw (const char *) errmsg;
    }

    void find_and_load_ICharacterClassifier(ICharacterClassifier &i,
                                            const char *resource) {
        i.load(stdio(open_resource(resource)));
    }
    void find_and_load_IRecognizeLine(IRecognizeLine &i,
                                      const char *resource) {
        i.load(stdio(open_resource(resource)));
    }
}
