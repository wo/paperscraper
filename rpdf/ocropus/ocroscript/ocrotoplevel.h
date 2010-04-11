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
// Project: ocropus
// File: ocrotoplevel.h
// Purpose: scripting interface to OCRopus
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

// -*- C -*-

#ifndef ocrotoplevel_h__
#define ocrotoplevel_h__

#ifdef __cplusplus
extern "C" {
#endif

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <signal.h>

void ocroscript_openlibs(lua_State *L);
lua_State *ocroscript_init_minimal();
void ocroscript_openlibs(lua_State *L);
lua_State *ocroscript_init();
int ocroscript_main(int argc, char **argv);

void ocroscript_set_number(const char *name,double value);
double ocroscript_get_number(const char *name);

void ocroscript_set_string(const char *name,const char *value);
char *ocroscript_get_string(const char *name);

void ocroscript_set_image(const char *name,const unsigned char *image,int w,int h,int channels);
void ocroscript_get_image(unsigned char *image,int *w,int *h,int *channels,const char *name);

void ocroscript_set_raster(const char *name,const unsigned char *image,int w,int h,int channels);
void ocroscript_get_raster(unsigned char *image,int *w,int *h,int *channels,const char *name);

char *ocroscript_eval_string(const char *expression);
double ocroscript_eval_number(const char *expression);

#ifdef __cplusplus
}
#endif

/* These have C++ linkage, so you simply can't call them from C */

void luaopen_sysutil(lua_State *);
void luaopen_narray(lua_State *);
void luaopen_nustring(lua_State *);
void luaopen_image(lua_State *);
void luaopen_ocr(lua_State *);
void luaopen_fst(lua_State *);
void luaopen_tess(lua_State *);
void luaopen_graphics(lua_State *);
void luaopen_lepton(lua_State *);

#endif
