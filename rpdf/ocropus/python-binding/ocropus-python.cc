// Copyright 2006-2008 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
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
// File: ocropus-python.cc
// Purpose: python interface for ocropus
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

// For some unknown reason, I can't make it work if it consists of many files.
// So all OCRopus-Python interface will be in one file then. - I.M.

#include <Python.h>
#include <numpy/arrayobject.h>
#include "colib.h"
extern "C" {
#include "lua.h"
#include "lualib.h"
}
#include "tolua++.h"
#include "ocrotoplevel.h"

// TODO: add checks for weird numpy dimensions

using namespace colib;

namespace {

    template<class T> void internal_numpy_to_colib(narray<T> &dest,
                                                   PyObject *src,
                                                   int py_type_id) {
        PyObject *obj = PyArray_ContiguousFromObject(src, py_type_id, 0, 0);
        PyArrayObject *a = (PyArrayObject *) obj;
        int ndim;
        int n0 = 0, n1 = 0, n2 = 0, n3 = 0;
        ndim = PyArray_NDIM(a);
        
        if(ndim > 0) n0 = PyArray_DIM(a, 0);
        if(ndim > 1) n1 = PyArray_DIM(a, 1);
        if(ndim > 2) n2 = PyArray_DIM(a, 2);
        if(ndim > 3) n3 = PyArray_DIM(a, 3);
        
        dest.resize(n0, n1, n2, n3);
        int n = PyArray_Size(obj);
        memcpy(dest.data, PyArray_DATA(a), n * sizeof(T));
        Py_DECREF(obj);
    }

    template<class T> PyObject *internal_colib_to_numpy(narray<T> &src,
                                                        int py_type_id) {
        int size[4];

        for(int i = 0; i < src.rank(); i++)
            size[i] = src.dim(i);
        
        PyObject *dest = PyArray_FromDims(src.rank(), size, py_type_id);
        memcpy(PyArray_DATA(dest), src.data, src.total * sizeof(T));
        
        return PyArray_Return((PyArrayObject *) dest);
    }

    template<class T> void internal_assign_colib_to_numpy(PyObject *dst,
                                                          narray<T> &src,
                                                          int py_type_id) {
        npy_intp size[4];

        for(int i = 0; i < src.rank(); i++)
            size[i] = src.dim(i);
        
        PyArray_Dims dims;
        dims.len = src.rank();
        dims.ptr = size;

        PyObject *ref = PyArray_Resize((PyArrayObject *) dst, &dims,
                                        1, PyArray_CORDER);
        if(!ref)
            return;
        memcpy(PyArray_DATA(dst), src.data, src.total * sizeof(T));
        Py_DECREF(ref);
    }

}

namespace ocropus {
    void numpy_to_colib(bytearray &dest, PyObject *src) {
        internal_numpy_to_colib(dest, src, PyArray_UBYTE);
    }
    void numpy_to_colib(intarray &dest, PyObject *src) {
        internal_numpy_to_colib(dest, src, PyArray_INT);
    }
    void numpy_to_colib(floatarray &dest, PyObject *src) {
        internal_numpy_to_colib(dest, src, PyArray_FLOAT);
    }
    PyObject *colib_to_numpy(bytearray &src) {
        return internal_colib_to_numpy(src, PyArray_UBYTE);
    }
    PyObject *colib_to_numpy(intarray &src) {
        return internal_colib_to_numpy(src, PyArray_INT);
    }
    PyObject *colib_to_numpy(floatarray &src) {
        return internal_colib_to_numpy(src, PyArray_FLOAT);
    }
    void assign_colib_to_numpy(PyObject *dst, bytearray &src) {
        return internal_assign_colib_to_numpy(dst, src, PyArray_UBYTE);
    }
    void assign_colib_to_numpy(PyObject *dst, intarray &src) {
        return internal_assign_colib_to_numpy(dst, src, PyArray_INT);
    }
    void assign_colib_to_numpy(PyObject *dst, floatarray &src) {
        return internal_assign_colib_to_numpy(dst, src, PyArray_FLOAT);
    }
    void *numpy_to_new_narray(const char **ptype, PyObject *obj) {
        if(!PyArray_Check(obj)) return NULL;
        PyArrayObject *a = (PyArrayObject *) obj;
        switch(PyArray_DESCR(a)->type_num) {
            case PyArray_UBYTE: {
                bytearray *result = new bytearray();
                numpy_to_colib(*result, obj);
                *ptype = "bytearray";
                return result;
            }
            case PyArray_INT: {
                intarray *result = new intarray();
                numpy_to_colib(*result, obj);
                *ptype = "intarray";
                return result;
            }
            case PyArray_FLOAT: {
                floatarray *result = new floatarray();
                numpy_to_colib(*result, obj);
                *ptype = "floatarray";
                return result;
            }
            default:
                return NULL;
        }
    }
}

using namespace ocropus;

namespace {

#if 0
    typedef struct {
        PyObject_HEAD
        void *stuff;
    } LuaBox;

    static PyTypeObject LuaBoxType = {
        PyObject_HEAD_INIT(NULL)
        0,                         /*ob_size*/
        "LuaBox",                  /*tp_name*/
        sizeof(LuaBox),            /*tp_basicsize*/
        0,                         /*tp_itemsize*/
        0,                         /*tp_dealloc*/
        0,                         /*tp_print*/
        0,                         /*tp_getattr*/
        0,                         /*tp_setattr*/
        0,                         /*tp_compare*/
        0,                         /*tp_repr*/
        0,                         /*tp_as_number*/
        0,                         /*tp_as_sequence*/
        0,                         /*tp_as_mapping*/
        0,                         /*tp_hash */
        0,                         /*tp_call*/
        0,                         /*tp_str*/
        0,                         /*tp_getattro*/
        0,                         /*tp_setattro*/
        0,                         /*tp_as_buffer*/
        Py_TPFLAGS_DEFAULT,        /*tp_flags*/
        "Lua objects opaque to Python", /* tp_doc */
    };
#endif

    bool numpy_to_lua(lua_State *S, PyObject *obj) {
        const char *ptype;
        void *a = ocropus::numpy_to_new_narray(&ptype, obj);
        if(!a) return false;
        tolua_pushusertype(S, a, ptype);
        return true;
    }
};

namespace ocropus {

    void python_object_to_lua(lua_State *S, PyObject *obj) {
        if(obj == Py_None)
            lua_pushnil(S);
        else if(PyBool_Check(obj))
            lua_pushboolean(S, obj == Py_True);
        else if(PyInt_Check(obj))
	    lua_pushnumber(S, PyInt_AS_LONG(obj));
	else if(PyFloat_Check(obj))
	    lua_pushnumber(S, PyFloat_AS_DOUBLE(obj));
	else if(PyString_Check(obj))
	    lua_pushlstring(S, PyString_AS_STRING(obj),
	      		       PyString_GET_SIZE(obj));   
        else if(!numpy_to_lua(S, obj)) // try arrays...
            tolua_pushusertype(S, obj, "Python object"); // last resort: boxing
    }

    PyObject *lua_object_to_python(lua_State *S, int index) {
        // Lua's traditional negative indices won't work directly due to a bug 
        // in tolua_isusertype(). But we can this hack about it.
        if (index < 0)
            index = lua_gettop(S) + index + 1;
        switch(lua_type(S, index)) {
            case LUA_TNONE:
                throw "invalid stack index passed to lua_to_python()";
            case LUA_TNIL:
                Py_RETURN_NONE;
            case LUA_TNUMBER:
                return PyFloat_FromDouble(lua_tonumber(S, index));
            case LUA_TBOOLEAN:
                if(lua_toboolean(S, index))
                    Py_RETURN_TRUE;
                else
                    Py_RETURN_FALSE;
            case LUA_TSTRING:
                return PyString_FromStringAndSize(lua_tostring(S, index),
		                                  lua_strlen(S, index));
            case LUA_TLIGHTUSERDATA: 
            case LUA_TUSERDATA:
            case LUA_TTHREAD:
            case LUA_TTABLE:
            case LUA_TFUNCTION: {
                tolua_Error err;
                if(tolua_isusertype(S, index, "floatarray", 0, &err)) {
                    return colib_to_numpy(*(floatarray *)
                                            tolua_tousertype(S, index, 0));
                } else if(tolua_isusertype(S, index, "bytearray", 0, &err)) {
                    return colib_to_numpy(*(bytearray *)
                                            tolua_tousertype(S, index, 0));
                } else if(tolua_isusertype(S, index, "intarray", 0, &err)) {
                    return colib_to_numpy(*(intarray *)
                                            tolua_tousertype(S, index, 0));
                } else if(tolua_isusertype(S, index, "Python object", 0, &err)){
                    PyObject *obj = (PyObject *) tolua_tousertype(S, index, 0);
                    Py_INCREF(obj);
                    return obj;
                } else {
                    throw "boxing Lua objects into Python is not supported";
                }
            }
            // shouldn't fall through, but there's just an error message anyway
            default:
                throw "something strange happened in lua_to_python()";
        }
    }

    void assign_lua_object_to_python(PyObject *dst, lua_State *S, int index) {
        // as in lua_object_to_python()
        if (index < 0)
            index = lua_gettop(S) + index + 1;

        if(lua_type(S, index) != LUA_TUSERDATA)
            return;

        tolua_Error err;
        if(tolua_isusertype(S, index, "floatarray", 0, &err)) {
            assign_colib_to_numpy(dst, *(floatarray *)
                                       tolua_tousertype(S, index, 0));
        } else if(tolua_isusertype(S, index, "bytearray", 0, &err)) {
            assign_colib_to_numpy(dst, *(bytearray *)
                                       tolua_tousertype(S, index, 0));
        } else if(tolua_isusertype(S, index, "intarray", 0, &err)) {
            assign_colib_to_numpy(dst, *(intarray *)
                                       tolua_tousertype(S, index, 0));
        }

    }
}

static lua_State *L;

static PyObject *ocropus_eval_lua(PyObject *self, PyObject *args) {
    char *string;
    if(!PyArg_ParseTuple(args, "s", &string))
        return NULL;
    if(luaL_dostring(L, string))
        return NULL;
    Py_RETURN_NONE;
}

static PyObject *ocropus_get_global(PyObject *self, PyObject *args) {
    char *name;
    if(!PyArg_ParseTuple(args, "s", &name))
        return NULL;
    lua_getglobal(L, name);
    PyObject *result = lua_object_to_python(L, -1);
    lua_pop(L, 1);
    return result;
}

static PyObject *ocropus_set_global(PyObject *self, PyObject *args) {
    char *name;
    PyObject *obj;
    if(!PyArg_ParseTuple(args, "sO", &name, &obj))
        return NULL;
    python_object_to_lua(L, obj);
    lua_setglobal(L, name);
    Py_RETURN_NONE;
}

static PyObject *ocropus_call_global(PyObject *self, PyObject *args) {
    char *name;
    PyObject *tuple;
    if(!PyArg_ParseTuple(args, "sO!", &name, &PyTuple_Type, &tuple))
        return NULL;
    int n = PyTuple_Size(tuple);
    lua_checkstack(L, 2 * n + 1);
    // pushing the first time - later we'll return here and stuff numpy arrays
    for(int i = 0; i < n; i++) {
        python_object_to_lua(L, PyTuple_GetItem(tuple, i));
    }
    lua_getglobal(L, name);
    // make a copy of that n objects we've pushed 
    for(int i = 0; i < n; i++) {
        lua_pushvalue(L, -n-1);
    }
    lua_call(L, n, 1);
    PyObject *result = lua_object_to_python(L, -1);
    lua_pop(L, 1);
    // now we have n objects that we need to assign back
    for(int i = 0; i < n; i++) {
        assign_lua_object_to_python(PyTuple_GetItem(tuple, i), L, i - n);
    }
    lua_pop(L, n);
    
    return result;
}


static PyMethodDef methods[] = {
    {"eval", ocropus_eval_lua, METH_VARARGS, "Evaluate a string in Lua."},
    {"get", ocropus_get_global, METH_VARARGS, "Get a global variable."},
    {"set", ocropus_set_global, METH_VARARGS, "Set a global variable."},
    {"call", ocropus_call_global, METH_VARARGS, "Call a global function."},
    {NULL, NULL, 0, NULL}
};

PyMODINIT_FUNC initocropus(void) {
    (void) Py_InitModule("ocropus", methods);
    L = ocroscript_init(); // TODO: deinitialize appropriately (?)
    import_array();
}

