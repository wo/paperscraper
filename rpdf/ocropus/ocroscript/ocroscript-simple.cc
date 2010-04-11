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
// File: ocroscript-simple.cc
// Purpose: scripting interface to OCRopus
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <signal.h>
}

#include "colib.h"

extern void luaopen_sysutil(lua_State *);
extern void luaopen_narray(lua_State *);
extern void luaopen_nustring(lua_State *);
extern void luaopen_image(lua_State *);
extern void luaopen_ocr(lua_State *);
extern void luaopen_fst(lua_State *);
extern void luaopen_graphics(lua_State *);
// extern void luaopen_tess(lua_State *);
// extern void luaopen_lepton(lua_State *);

int main(int argc,char **argv) {
    lua_State *L = lua_open();

    luaL_openlibs(L);

    luaopen_sysutil(L);
    luaopen_narray(L);
    luaopen_nustring(L);
    luaopen_image(L);
    luaopen_ocr(L);
    luaopen_fst(L);
    luaopen_graphics(L);
    // luaopen_tess(L);
    // luaopen_lepton(L);

    int status = -1;

    try {
        status = luaL_dofile(L,argv[1]);
    } catch(char const *msg) {
        fprintf(stderr,"EXCEPTION: %s\n",msg);
        exit(1);
    } catch(...) {
        fprintf(stderr,"UNEXPECTED EXCEPTION\n");
        exit(1);
    }

    if(status!=0) {
        fprintf(stderr,"error: %s\n",lua_tostring(L,-1));
    }
    lua_close(L);
    return 0;
}
