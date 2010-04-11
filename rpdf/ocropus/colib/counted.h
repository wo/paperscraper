// -*- C++ -*-

// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// Copyright 1995-2005 Thomas M. Breuel.
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
// File: counted.h
// Purpose:
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

/// \file counted.h
/// \brief Link counting smart pointers.

#ifndef h_counted_
#define h_counted_

/// A smart pointer with a link counter.
template <class T>
class counted {
    struct TC : T {
        int refcount_;
    };
    TC *p;
public:
    counted() {
        p = 0;
    }
    counted(const counted<T> &other) {
        other.incref();
        p = other.p;
    }
    counted(counted<T> &other) {
        other.incref();
        p = other.p;
    }
    ~counted() {
        decref();
        p = 0;
    }
    void operator=(counted<T> &other) {
        other.incref();
        decref();
        p = other.p;
    }
    void operator=(const counted<T> &other) {
        other.incref();
        decref();
        p = other.p;
    }
    void operator*=(counted<T> &other) {
        other.incref();
        decref();
        p = other.p;
        other.drop();
    }
    void operator*=(const counted<T> &other) {
        other.incref();
        decref();
        p = other.p;
        other.drop();
    }
    bool allocated() {
        return !p;
    }
    void allocate() {
        p = new TC();
        p->refcount_ = 1;
    }
    operator bool() {
        return !!p;
    }
    void drop() {
        decref();
        p = 0;
    }
    T &operator *() {
        if(!p) allocate();
        return *(T*)p;
    }
    T *operator->() {
        if(!p) allocate();
        return (T*)p;
    }
    operator T&() {
        if(!p) allocate();
        return *(T*)p;
    }
    operator T*() {
        if(!p) allocate();
        return (T*)p;
    }
    void incref() const {
        check();
        if(p) {
            if(p->refcount_>10000000) abort();
            if(p->refcount_<0) abort();
            p->refcount_++;
        }
    }
    void decref() const {
        check();
        if(p) {
            if(--p->refcount_==0) delete p;
            ((counted<T>*)this)->p = 0;
        }
    }
    void check() const {
        if(!p) return;
        if(p->refcount_>10000000) abort();
        if(p->refcount_<0) abort();
    }
};

#endif
