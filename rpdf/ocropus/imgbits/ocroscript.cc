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

extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <signal.h>
}

#include "ocrotoplevel.h"
void luaopen_imgbitscmds(lua_State *L);
void luaopen_imgrlecmds(lua_State *L);

int main(int argc,char **argv) {
    lua_State *L = ocroscript_init_minimal();
    luaopen_sysutil(L);
    luaopen_narray(L);
    luaopen_nustring(L);
    luaopen_image(L);
    luaopen_graphics(L);
    luaopen_ocr(L);
    //luaopen_lepton(L);
    luaopen_imgbitscmds(L);
    luaopen_imgrlecmds(L);
    return ocroscript_main(argc,argv);
}
