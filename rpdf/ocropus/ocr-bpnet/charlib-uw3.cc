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
#include "imgio.h"
#include "imglib.h"
#include "ocr-utils.h" // FIXME this is a circular dependency

using namespace imgio;
using namespace imglib;
using namespace colib;

#define GOOD_LINE_START "Font:"

namespace ocropus {


    static bool ends_with(const char *str, const char *suf) {
        int len_str = strlen(str);
        int len_suf = strlen(suf);
        if (len_str < len_suf)
            return false;
        return !strcmp(suf, str + len_str - len_suf);
    }


    struct UW3Character : ICharacter {
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


    struct UW3Charlib : ICharacterLibrary {
        strbuf directory;
        strbuf suffix;
        bytearray image;
        int currentSection;
        narray<UW3Character> characters;
        narray<strbuf> fileList;

        void parse_tru(strbuf path) {
            narray<strbuf> content; // because we can't have growable array of Characters
            FILE *f = fopen(path, "r");
            ALWAYS_ASSERT(f);
            char buf[1000];
            while (fgets(buf, sizeof(buf), f)) {
                if (strncmp(buf, GOOD_LINE_START, strlen(GOOD_LINE_START)))
                    continue;
                if (strstr(buf, "cmmex") || strstr(buf, "cmex"))
                    continue;
                char *s = buf + strlen(GOOD_LINE_START);
                strbuf str;
                str.ensure(strlen(s));
                strcpy(str,s);
                content.push(str);
            }
            fclose(f);

            characters.resize(content.length());
            for (int i = 0; i < content.length(); i++) {
                int x, y, w, h, code;
                char font[100];
                int res = sscanf(content[i], "%d %d %d %d %s %d", &x, &y, &w, &h, font, &code);
                ALWAYS_ASSERT(res == 6);
                crop(characters[i].image(), image, x, image.dim(1) - y - h, w, h);

                // Fix some idiosyncrasies of UW3 database.
                if(strstr(content[i], "\tcmmi")) {
                    switch (code) {
                    case ';': code = ','; break;
                    case ':': code = '.'; break;
                    case '=': code = '/'; break;
                    }
                } else if(strstr(content[i], "\tcmsy")) {
                    switch (code) {
                    case 0: code = '-'; break;
                    case 1: code = '.'; break;
                    }
                }

                if (code == '{' && w > h * 2) {
                    code = '-';
                }

                characters[i].m_code = code;
                characters[i].description = content[i];
            }
        }

        void loadSection(int index) {
            strbuf tru;
            tru.ensure(strlen(fileList[index])+1);
            strcpy(tru,fileList[index]);
            char buf[5];
            strncpy(buf, tru, sizeof(buf));
            buf[sizeof(buf)-1] = '\0';
            strbuf pic;
            pic.ensure(strlen(buf)+strlen(suffix)+1);
            strcpy(pic,buf);
            strcat(pic,suffix);
            strbuf tru_path;
            tru_path.ensure(strlen(directory)+strlen("GROUND/")+strlen(tru)+1);
            strcpy(tru_path,directory);
            strcat(tru_path,"GROUND/");
            strcat(tru_path,tru);
            strbuf pic_path;
            pic_path.ensure(strlen(directory)+strlen("IMAGEBIN/")+strlen(pic)+1);
            strcpy(pic_path,directory);
            strcat(pic_path,"IMAGEBIN/");
            strcat(pic_path,pic);
            strbuf cmd;
            cmd.ensure(strlen("tifftopnm \"")+strlen(pic_path)+strlen("\"")+1);
            strcpy(cmd,"tifftopnm \"");
            strcat(cmd,pic_path);
            strcat(cmd,"\"");// 2>/dev/null");
            FILE *f = popen(cmd, "r");
            if (!f) {
                perror(cmd);
                exit(1);
            }
            read_pnm_gray(f, image);
            fclose(f);
            parse_tru(tru_path);
        }

        // Reads the list of files from YMTRANS.TBL.
        void ls(narray<strbuf> &result, strbuf directory) {
            result.clear();
            strbuf path;
            path.ensure(strlen(directory)+strlen("YMTRANS.TBL")+1);
            strcat(path,"YMTRANS.TBL");
            FILE *f = fopen(path, "r");
            ALWAYS_ASSERT(f);
            char buf[1000];
            while (fgets(buf, sizeof(buf), f)) {
                if (*buf != 'F')
                    continue;
                char *s = buf + 1;
                char foo[100], file[100];
                int res = sscanf(s, "%s %s", foo, file);
                ALWAYS_ASSERT(res == 2);
                strbuf str;
                str.ensure(strlen(file)+1);
                strcpy(str,file);
                result.push(str);
            }
            fclose(f);
        }


        UW3Charlib(const char *dir, const char *suf) {
            directory.ensure(strlen(dir)+2);
            strcpy(directory,dir);
            suffix.ensure(strlen(suf)+1);
            strcpy(suffix,suf);
            if (directory[strlen(directory) - 1] != '/')
                strcat(directory,"/");
            strbuf tmp;
            tmp.ensure(strlen(directory)+strlen("GROUND/")+1);
            strcpy(tmp,directory);
            strcat(tmp,"GROUND/");
            ls(fileList, tmp);
            for (int i = 0; i < fileList.length(); i++) {
                if (!ends_with(fileList[i], ".TRU")) {
                    remove_element(fileList, i);
                    i--;
                }
            }
            currentSection = 0;
            loadSection(0);
        }

        virtual const char *description() {
            return "UW3Charlib";
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
            return characters.length();
        }

        virtual ICharacter &character(int index) {
            return characters[index];
        }
    };

    ICharacterLibrary *make_uw3_charlib(const char *directory, const char *suffix) {
        return new UW3Charlib(directory, suffix);
    }

};
