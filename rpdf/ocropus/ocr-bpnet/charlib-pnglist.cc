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
#include "imgio.h"
#include "charlib.h"
#include "ocr-utils.h"                  // FIXME circular dependency

using namespace imgio;
using namespace colib;

namespace ocropus {

    struct PngListCharacter : ICharacter {
        bytearray m_image;
        strbuf description;
        int m_code;

        virtual bytearray &image() { return m_image; }
        virtual int code()         { return m_code;  }
        virtual int xHeight()      { return 0; }
        virtual int baseline()     { return 0; }
        virtual int ascender()     { return 0; }
        virtual int descender()    { return 0; }
        virtual const char *info() { return (char*)(description); }
    };


    struct PngListCharlib : ICharacterLibrary {
        int currentSection;
        PngListCharacter m_character;
        narray<int> codes;
        narray<strbuf> fileList;

        void loadSection(int index) {
            strbuf path;
            path.ensure(strlen(fileList[index])+1);
            strcpy(path,fileList[index]);
            read_png(m_character.m_image, stdio((char*)(path), "r"), true);
            m_character.m_code = codes[index];
            m_character.description.ensure(strlen(path)+1);
            strcpy(m_character.description,path);
        }

        PngListCharlib(const char *list_path) {
            stdio list(list_path, "r");
            while (1) {
                char code[100];
                char path[100];
                if (fscanf(list, "%s %s", code, path) != 2)
                    break;
                codes.push(code[0]);
                strbuf str;
                str.ensure(strlen(path)+1);
                strcpy(str,path);
                fileList.push(str);
            }
            currentSection = 0;
            loadSection(0);
        }

        virtual const char *description() {
            return "PngListCharlib";
        }

        virtual void init(const char **argv) {
        }

        virtual void switchToSection(int index) {
            ASSERT(index >= 0  &&  index < sectionsCount());
            loadSection(index);
            currentSection = index;
        }

        virtual int sectionsCount() {
            return fileList.length();
        }

        virtual int currentSectionIndex() {
            return currentSection;
        }

        virtual int charactersCount() {
            return 1;
        }

        virtual ICharacter &character(int index) {
            return m_character;
        }
    };

    ICharacterLibrary *make_pnglist_charlib(const char *list) {
        return new PngListCharlib(list);
    }

};
