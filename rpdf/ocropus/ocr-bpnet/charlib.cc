// -*- C++ -*-

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
// Project:
// File:
// Purpose:
// Responsible: kapry
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "charlib.h"

using namespace colib;

namespace ocropus {

    struct SliceLibrary : public ICharacterLibrary {
        ICharacterLibrary &charlib;
        int from, to;

        virtual const char *description() {
            return "charlib slice";
        }

        virtual void init(const char **argv) {
        }

        virtual int sectionsCount() {
            return to - from;
        }

        virtual void switchToSection(int no) {
            charlib.switchToSection(from + no);
        }

        virtual int currentSectionIndex() {
            return charlib.currentSectionIndex() - from;
        }

        virtual int charactersCount() {
            return charlib.charactersCount();
        }

        virtual ICharacter &character(int index) {
            return charlib.character(index);
        }

        SliceLibrary(ICharacterLibrary &l, int f, int t) : charlib(l), from(f), to(t) {
            ASSERT(0 <= f && f < l.sectionsCount());
            ASSERT(0 <= t && t <= l.sectionsCount());
            ASSERT(f <= t);
        }
    };

    ICharacterLibrary *make_slice_charlib(ICharacterLibrary &charlib, int from_incl, int upto_excl) {
        return new SliceLibrary(charlib, from_incl, upto_excl);
    }


    static int mangle(int c) {
        char from[] = "0OI1CPSVWXZ'";
        char to  [] = "oollcpsvwxz,";
        char *p = strchr(from, c);
        if (!p)
            return c;
        else
            return to[p - from];
    }


    struct FilterCharacter : ICharacter {
        ICharacter *character;

        virtual bytearray &image() { return character->image(); }
        virtual int code() { return mangle(character->code()); }
        virtual int xHeight() { return character->xHeight(); }
        virtual int baseline() { return character->baseline(); }
        virtual int descender() { return character->descender(); }
        virtual int ascender() { return character->ascender(); }

        FilterCharacter() : character(NULL) {
        }

        virtual const char *info() {
            return character->info();
        }
    };


    struct FilterLibrary : public ICharacterLibrary {
        ICharacterLibrary &charlib;
        narray<FilterCharacter> characters;

        virtual const char *description() {
            return "FilterLibrary";
        }

        virtual void init(const char **argv) {
        }

        virtual int sectionsCount() {
            return charlib.sectionsCount();
        }

        virtual void switchToSection(int no) {
            charlib.switchToSection(no);
            fill();
        }

        virtual int currentSectionIndex() {
            return charlib.currentSectionIndex();
        }

        virtual int charactersCount() {
            return charlib.charactersCount();
        }

        void fill() {
            characters.resize(charlib.charactersCount());
            for (int i = 0; i < charlib.charactersCount(); i++) {
                characters[i].character = &charlib.character(i);
            }
        }

        virtual ICharacter &character(int index) {
            return characters(index);
        }

        FilterLibrary(ICharacterLibrary &l) : charlib(l) {
            fill();
        }

    };

    ICharacterLibrary *make_filter_charlib(ICharacterLibrary &c) {
        return new FilterLibrary(c);
    }

    void dump_charlib(Logger &log, ICharacterLibrary &charlib) {
        for(int i = 0; i < charlib.sectionsCount(); i++) {
            charlib.switchToSection(i);
            log("<H3>Section %d</H3>", i);
            for(int j = 0; j < charlib.charactersCount(); j++) {
                log.format("code: %c", charlib.character(j).code());
                log("image", charlib.character(j).image());
            }
        }
    }

}; //namespace
