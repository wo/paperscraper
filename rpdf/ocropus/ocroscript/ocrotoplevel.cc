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

#include "colib.h"
#include "ocrotoplevel.h"

#define LUA_PROGNAME "ocroscript"
#define LUA_PROMPT "> "
#define LUA_PROMPT2 ">> "
#define LUA_MAXINPUT 1024

#define LUA_USE_ISATTY

#include <stdio.h>
extern "C" {
extern char *readline(const char *);
extern void add_history(const char *);
}
#define lua_readline(L,b,p)     ((void)L, ((b)=readline(p)) != NULL)
#if defined(LUA_USE_EDITLINE)
#define lua_saveline(L,idx) \
        if (lua_strlen(L,idx) > 0)  /* non-empty line? */ \
          add_history(lua_tostring(L, idx));  /* add it to history */
#define lua_freeline(L,b)       ((void)L, free(b))
#endif

#if defined(LUA_USE_ISATTY)
#include <unistd.h>
#define lua_stdin_is_tty()      isatty(0)
#elif defined(LUA_WIN)
#include <io.h>
#include <stdio.h>
#define lua_stdin_is_tty()      _isatty(_fileno(stdin))
#else
#define lua_stdin_is_tty()      1  /* assume stdin is a tty */
#endif

// FIXME the Jamfile isn't passing this flag, so for now, this is a workaround
#ifndef OCROSCRIPTS
#define OCROSCRIPTS "/usr/local/share/ocropus/scripts/"
#endif
#ifndef OCRODATA
#define OCRODATA "/usr/local/share/ocropus/"
#endif

char *ocroscripts = OCROSCRIPTS;
char *ocrodata = OCRODATA;

lua_State *globalL;

extern void luaopen_system(lua_State *);
extern void luaopen_narray(lua_State *);
extern void luaopen_nustring(lua_State *);
extern void luaopen_image(lua_State *);
extern void luaopen_ocr(lua_State *);
extern void luaopen_fst(lua_State *);
extern void luaopen_tess(lua_State *);
extern void luaopen_graphics(lua_State *);
extern void luaopen_imgbitscmds(lua_State *);
extern void luaopen_imgrlecmds(lua_State *);
#ifdef WITH_LEPT
extern void luaopen_lepton(lua_State *);
#endif

void ocroscript_openlibs(lua_State *L) {
    luaopen_sysutil(L);
    luaopen_narray(L);
    luaopen_nustring(L);
    luaopen_image(L);
    luaopen_ocr(L);
    luaopen_tess(L);
    luaopen_fst(L);
    luaopen_imgbitscmds(L);
    luaopen_imgrlecmds(L);
    luaopen_graphics(L);
#ifdef WITH_LEPT
    luaopen_lepton(L);
#endif
}

static const char *progname = LUA_PROGNAME;

static void lstop(lua_State *L, lua_Debug *ar) {
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);
  luaL_error(L, "interrupted!");
}


static void laction(int i) {
    signal(i, SIG_DFL); /* if another SIGINT happens before lstop,
                           terminate process (default action) */
    lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}


static void print_usage(void) {
    fprintf(stderr,
            "usage: %s [options] [script [args]].\n"
            "Available options are:\n"
            "  -e stat  execute string " LUA_QL("stat") "\n"
            "  -l name  require library " LUA_QL("name") "\n"
            "  -i       enter interactive mode after executing " LUA_QL("script") "\n"
            "  -v       show version information\n"
            "  --       stop handling options\n"
            "  -        execute stdin and stop handling options\n"
            ,
            progname);
    fflush(stderr);
}


static void l_message(const char *pname, const char *msg) {
    if(pname) fprintf(stderr, "%s: ", pname);
    fprintf(stderr, "%s\n", msg);
    fflush(stderr);
}


static int report(lua_State *L, int status) {
    if(status && !lua_isnil(L, -1)) {
        const char *msg = lua_tostring(L, -1);
        if(msg == NULL) msg = "(error object is not a string)";
        l_message(progname, msg);
        lua_pop(L, 1);
    }
    return status;
}


static int traceback(lua_State *L) {
    lua_getfield(L, LUA_GLOBALSINDEX, "debug");
    if(!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return 1;
    }
    lua_getfield(L, -1, "traceback");
    if(!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return 1;
    }
    lua_pushvalue(L, 1);  /* pass error message */
    lua_pushinteger(L, 2);  /* skip this function and traceback */
    lua_call(L, 2, 1);  /* call debug.traceback */
    return 1;
}


static int docall(lua_State *L, int narg, int clear) {
    int status;
    int base = lua_gettop(L) - narg;  /* function index */
    lua_pushcfunction(L, traceback);  /* push traceback function */
    lua_insert(L, base);  /* put it under chunk and args */
    signal(SIGINT, laction);
    status = lua_pcall(L, narg,(clear ? 0 : LUA_MULTRET), base);
    signal(SIGINT, SIG_DFL);
    lua_remove(L, base);  /* remove traceback function */
    /* force a complete garbage collection in case of errors */
    if(status != 0) lua_gc(L, LUA_GCCOLLECT, 0);
    return status;
}


static void print_version(void) {
    // l_message(NULL, LUA_RELEASE "  " LUA_COPYRIGHT);
    l_message(NULL,"OCRoscript (interactive)");
}


static int getargs(lua_State *L, char **argv, int n) {
    int narg;
    int i;
    int argc = 0;
    while(argv[argc]) argc++;  /* count total number of arguments */
    narg = argc -(n + 1);  /* number of arguments to the script */
    luaL_checkstack(L, narg + 3, "too many arguments to script");
    for(i=n+1; i < argc; i++)
        lua_pushstring(L, argv[i]);
    lua_createtable(L, narg, n + 1);
    for(i=0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i - n);
    }
    return narg;
}


static int dofile(lua_State *L, const char *name) {
    int status = luaL_loadfile(L, name) || docall(L, 0, 1);
    return report(L, status);
}


static int dostring(lua_State *L, const char *s, const char *name) {
    int status = luaL_loadbuffer(L, s, strlen(s), name) || docall(L, 0, 1);
    return report(L, status);
}


static int dolibrary(lua_State *L, const char *name) {
    lua_getglobal(L, "require");
    lua_pushstring(L, name);
    return report(L, lua_pcall(L, 1, 0, 0));
}


static const char *get_prompt(lua_State *L, int firstline) {
    const char *p;
    lua_getfield(L, LUA_GLOBALSINDEX, firstline ? "_PROMPT" : "_PROMPT2");
    p = lua_tostring(L, -1);
    if(p == NULL) p =(firstline ? LUA_PROMPT : LUA_PROMPT2);
    lua_pop(L, 1);  /* remove global */
    return p;
}


static int incomplete(lua_State *L, int status) {
    if(status == LUA_ERRSYNTAX) {
        size_t lmsg;
        const char *msg = lua_tolstring(L, -1, &lmsg);
        const char *tp = msg + lmsg -(sizeof(LUA_QL("<eof>")) - 1);
        if(strstr(msg, LUA_QL("<eof>")) == tp) {
            lua_pop(L, 1);
            return 1;
        }
    }
    return 0;  /* else... */
}


static int pushline(lua_State *L, int firstline) {
#if not defined(LUA_USE_EDITLINE)
    try{
        readline(0);
    } catch(const char* msg) {
        //fprintf(stderr, msg);
    }
    return 0;
#else
    char buffer[LUA_MAXINPUT];
    char *b = buffer;
    size_t l;
    const char *prmt = get_prompt(L, firstline);
    if(lua_readline(L, b, prmt) == 0)
        return 0;  /* no input */

    l = strlen(b);
    if(l > 0 && b[l-1] == '\n')  /* line ends with newline? */
        b[l-1] = '\0';  /* remove it */
    if(firstline && b[0] == '=')  /* first line starts with `=' ? */
        lua_pushfstring(L, "return %s", b+1);  /* change it to `return' */
    else
        lua_pushstring(L, b);
    lua_freeline(L, b);
    return 1;
#endif
}


static int loadline(lua_State *L) {
    int status;
    lua_settop(L, 0);
    if(!pushline(L, 1))
        return -1;  /* no input */
    for(;;) {  /* repeat until gets a complete line */
        status = luaL_loadbuffer(L, lua_tostring(L, 1), lua_strlen(L, 1), "=stdin");
        if(!incomplete(L, status)) break;  /* cannot try to add lines? */
        if(!pushline(L, 0))  /* no more input? */
            return -1;
        lua_pushliteral(L, "\n");  /* add a new line... */
        lua_insert(L, -2);  /* ...between the two lines */
        lua_concat(L, 3);  /* join them */
    }
#if defined(LUA_USE_EDITLINE)
    lua_saveline(L, 1);
#endif
    lua_remove(L, 1);  /* remove line */
    return status;
}


static void dotty(lua_State *L) {
    int status;
    const char *oldprogname = progname;
    progname = NULL;
    while((status = loadline(L)) != -1) {
        if(status == 0) status = docall(L, 0, 0);
        report(L, status);
        if(status == 0 && lua_gettop(L) > 0) {  /* any result to print? */
            lua_getglobal(L, "print");
            lua_insert(L, 1);
            if(lua_pcall(L, lua_gettop(L)-1, 0, 0) != 0)
                l_message(progname, lua_pushfstring(L,
                                                    "error calling " LUA_QL("print") " (%s)",
                                                    lua_tostring(L, -1)));
        }
    }
    lua_settop(L, 0);  /* clear stack */
    fputs("\n", stdout);
    fflush(stdout);
    progname = oldprogname;
}


static int handle_script(lua_State *L, char **argv, int n) {
    //char buf[10000];
    int status;
    const char *fname;
    int narg = getargs(L, argv, n);  /* collect arguments */
    lua_setglobal(L, "arg");
    fname = argv[n];
    lua_pushstring(L, fname);
    lua_setglobal(L, "arg_script_name");
    if(strcmp(fname, "-") == 0 && strcmp(argv[n-1], "--") != 0) {
        fname = NULL;  /* stdin */
    } else {
        FILE *stream = fopen(fname,"r");
        if(!stream) {
            luaL_loadstring(L, "require(arg_script_name)");
            lua_call(L, 0, 0);
            return 0; // we won't be here in case of errors
            /*strcpy(buf,ocroscripts);
            strcat(buf,"/");
            strcat(buf,fname);
            strcat(buf,".lua");
            fname = buf;*/
        } else {
            fclose(stream);
        }
    }
    status = luaL_loadfile(L, fname);
    lua_insert(L, -(narg+1));
    if(status == 0)
        status = docall(L, narg, 0);
    else
        lua_pop(L, narg);      
    return report(L, status);
}


/* check that argument has no extra characters at the end */
#define notail(x) {if((x)[2] != '\0') return -1;}


static int collectargs(char **argv, int *pi, int *pv, int *pe) {
    int i;
    for(i = 1; argv[i] != NULL; i++) {
        if(argv[i][0] != '-')  /* not an option? */
            return i;
        switch(argv[i][1]) {  /* option */
        case '-':
            notail(argv[i]);
            return(argv[i+1] != NULL ? i+1 : 0);
        case '\0':
            return i;
        case 'i':
            notail(argv[i]);
            *pi = 1;  /* go through */
        case 'v':
            notail(argv[i]);
            *pv = 1;
            break;
        case 'e':
            *pe = 1;  /* go through */
        case 'l':
            if(argv[i][2] == '\0') {
                i++;
                if(argv[i] == NULL) return -1;
            }
            break;
        default: return -1;  /* invalid option */
        }
    }
    return 0;
}


static int runargs(lua_State *L, char **argv, int n) {
    int i;
    for(i = 1; i < n; i++) {
        if(argv[i] == NULL) continue;
        lua_assert(argv[i][0] == '-');
        switch(argv[i][1]) {  /* option */
        case 'e': {
            const char *chunk = argv[i] + 2;
            if(*chunk == '\0') chunk = argv[++i];
            lua_assert(chunk != NULL);
            if(dostring(L, chunk, "=(command line)") != 0)
                return 1;
            break;
        }
        case 'l': {
            const char *filename = argv[i] + 2;
            if(*filename == '\0') filename = argv[++i];
            lua_assert(filename != NULL);
            if(dolibrary(L, filename))
                return 1;  /* stop if file fails */
            break;
        }
        default: break;
        }
    }
    return 0;
}

static int handle_luainit(lua_State *L) {
    const char *init = getenv(LUA_INIT);
    int status;
    if(init == NULL) return 0;  /* status OK */
    else if(init[0] == '@')
        status = dofile(L, init+1);
    else
        status = dostring(L, init, "=" LUA_INIT);
    if(status!=0) return status;
#define OCRO_INIT "OCRO_INIT"
    init = getenv(OCRO_INIT);
    if(init == NULL) return 0;  /* status OK */
    else if(init[0] == '@')
        status = dofile(L, init+1);
    else
        status = dostring(L, init, "=" OCRO_INIT);
    return status;
}

struct Smain {
    int argc;
    char **argv;
    int status;
};

static int pmain(lua_State *L) {
    struct Smain *s =(struct Smain *)lua_touserdata(L, 1);
    char **argv = s->argv;
    int script;
    int has_i = 0, has_v = 0, has_e = 0;
    if(globalL != L) {
        fprintf(stderr,"pmain called in wrong interpreter\n");
        exit(1);
    }

    // handle OCROSCRIPT environment variable as a path
    if(getenv("OCROSCRIPTS")) ocroscripts = getenv("OCROSCRIPTS");
    lua_pushstring(L, ocroscripts);
    lua_setglobal(L, "libdir");
    // The following line converts the path into a Lua-acceptable one.
    luaL_loadstring(L, "package.path=(libdir..';'):gsub(':',';'):gsub(';+',';'):gsub(';','/?.lua;')..package.path");
    lua_call(L, 0, 0);

    // handle OCRODATA environment variable as a directory
    lua_pushstring(L, ocrodata);
    lua_setglobal(L, "ocrodata");

    // handle command line arguments
    if(argv[0] && argv[0][0]) progname = argv[0];
    s->status = handle_luainit(L);
    if(s->status != 0) return 0;
    script = collectargs(argv, &has_i, &has_v, &has_e);
    if(script < 0) {  /* invalid args? */
        print_usage();
        s->status = 1;
        return 0;
    }
    if(has_v) print_version();
    s->status = runargs(L, argv,(script > 0) ? script : s->argc);
    if(s->status != 0) return 0;
    if(script)
        s->status = handle_script(L, argv, script);
    if(s->status != 0) return 0;
    if(has_i)
        dotty(L);
    else if(script == 0 && !has_e && !has_v) {
        if(lua_stdin_is_tty()) {
            print_version();
            dotty(L);
        }
        else dofile(L, NULL);  /* executes stdin as a file */
    }
    return 0;
}


lua_State *ocroscript_init_minimal() {
    if(globalL) 
        throw "ocropus already initialized";
    globalL = lua_open();
    if(globalL == NULL) 
        throw "cannot create toplevel interpreter";
    lua_State *L = globalL;
    lua_gc(L, LUA_GCSTOP, 0);  /* stop collector during initialization */
    luaL_openlibs(L);  /* open libraries */
    return L;
}

lua_State *ocroscript_init() {
    lua_State *L = ocroscript_init_minimal();
    ocroscript_openlibs(L);
    lua_gc(L, LUA_GCRESTART, 0);
    return L;
}


int ocroscript_main(int argc, char **argv) {
    int status;
    struct Smain s;
    s.argc = argc;
    s.argv = argv;
    lua_State *L = globalL;
    status = lua_cpcall(L, &pmain, &s);
    report(L, status);
    lua_close(L);
    return (status || s.status) ? EXIT_FAILURE : EXIT_SUCCESS;
}
