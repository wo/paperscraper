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
#include "grid.h"
#include "ocr-utils.h"                      // FIXME circular dependency

using namespace colib;

namespace ocropus {


    struct GridCharacter : ICharacter {
        bytearray m_image;
        int m_code;
        int m_xHeight;
        int m_baseline;
        int m_ascender;
        int m_descender;
        strbuf description;

        virtual ~GridCharacter() {}

        virtual bytearray &image() { return m_image;     }
        virtual int code()         { return m_code;      }
        virtual int xHeight()      { return m_xHeight;   }
        virtual int baseline()     { return m_baseline;  }
        virtual int ascender()     { return m_ascender;  }
        virtual int descender()    { return m_descender; }
        virtual const char *info() {
            return description; //kluge alert
        }
    };


    class GridCharacterLibrary : public ICharacterLibrary {
        narray<GridCharacter> characters;
        int current_section;
        int ascender, descender, xHeight, baseline;
        int grids_count;
        strbuf directory;
        bool use_garbage;

        int read_grids_count() {
            strbuf file_name;
            file_name.ensure(strlen(directory)+strlen("currentnumber")+1);
            strcpy(file_name,directory);
            strcat(file_name,"currentnumber");
            FILE *f = fopen(file_name, "r");
            if (!f) {
                perror(file_name);
                exit(1);
            }
            char buf[10];
            fgets(buf, sizeof(buf), f);
            int count = atoi(buf);
            ASSERT(count);
            fclose(f);
            return count;
        }

        bool is_garbage_section(int section_index) {
            return (use_garbage ? section_index % 2 : false);
        }

        int section_index_to_grid_index(int section_index) {
            return (use_garbage ? section_index / 2 + 1 : section_index + 1);
        }


        strbuf index_to_str(int index)
        {
            char buf[32];
            sprintf(buf, "%6d", index);
            for (int i=0;i<6;i++)
                if (buf[i] == ' ')
                    buf[i] = '0';
            strbuf str;
            str.ensure(strlen(buf)+1);
            strcpy(str,buf);
            return str;
        }


        void load_grid(Grid &g, const char *path)
        {
            FILE *f = fopen(path, "rb");
            if (!f)
                {
                    perror(path);
                    exit(1);
                }
            g.load(f);
            fclose(f);
        }

        void load_section(int index) {
            strbuf num;
            num.ensure(200);
            strcpy(num,index_to_str(section_index_to_grid_index(index)));
            strbuf file_suffix;
            file_suffix.ensure(200);
            strcpy(file_suffix,(is_garbage_section(index) ? "_garbage_grid.pgm" : "_char_grid.pgm"));
            strbuf file_name;
            file_name.ensure(strlen(num)+strlen(file_suffix)+1);
            strcpy(file_name,num);
            strcat(file_name,file_suffix);

            Grid g;
            strbuf aStr;
            aStr.ensure(strlen(directory)+strlen(file_name)+1);
            strcpy(aStr,directory);
            strcat(aStr,file_name);
            load_grid(g, aStr);

            bytearray a;
            int n;
            if (g.hasLineInfo()) {
                n = g.count() - 1;
                g.next(a); // skip line information
                g.getLineInformation(baseline, xHeight, descender, ascender);
            } else {
                baseline = xHeight = descender = ascender = 0;
                n = g.count();
            }

            characters.renew(n);
            for (int i=0;i<n;i++) {
                GridCharacter &c = characters[i];
                int result = g.next(c.m_image);
                ALWAYS_ASSERT(result);
                c.m_descender = descender;
                c.m_baseline = baseline;
                c.m_xHeight = xHeight;
                c.m_ascender = ascender;
                c.description.ensure(strlen(file_name)+1);
                strcpy(c.description,file_name);
            }

            if(is_garbage_section(index)) {
                for (int i=0;i<n;i++) {
                    characters[i].m_code = GARBAGE;
                }
            } else {
                file_name.ensure(strlen(num)+strlen("_transcript.txt")+1);
                strcpy(file_name,num);
                strcat(file_name,"_transcript.txt");
                strbuf tmpstr;
                tmpstr.ensure(strlen(directory)+strlen(file_name)+1);
                strcpy(tmpstr,directory);
                strcat(tmpstr,file_name);
                FILE *f = fopen(tmpstr, "r");
                narray<char> buf(n + 10);
                fgets(&buf[0], buf.length(), f); // reusing buf
                for(int i=0;i<n;i++) {
                    characters[i].m_code = buf[i];
                }
                fclose(f);
            }
        }

    public:

        virtual const char *description() {
            return "GridCharacterLibrary";
        }

        virtual void init(const char **argv) {
        }

        virtual int currentSectionIndex() {
            return current_section;
        }

        GridCharacterLibrary(const char *_directory, bool _use_garbage = true) :
            use_garbage(_use_garbage) {
            directory.ensure(strlen(_directory)+1);
            strcpy(directory,_directory);
            if (directory[strlen(directory) - 1] != '/')
                strcat(directory,"/");
            grids_count = read_grids_count();
            switchToSection(0);
        }

        virtual ~GridCharacterLibrary() {
        }

        virtual int sectionsCount() {
            return (use_garbage ? grids_count * 2 : grids_count);
        }

        virtual int current_section_index() {
            return current_section;
        }

        virtual void switchToSection(int index) {
            ASSERT(index >= 0  &&  index < sectionsCount());
            load_section(index);
            current_section = index;
        }

        virtual int charactersCount() {
            return characters.length();
        }

        virtual ICharacter &character(int index) {
            ASSERT(index >= 0  &&  index < charactersCount());
            return characters[index];
        }
    };

    ICharacterLibrary *make_grid_charlib(const char *directory, bool use_garbage) {
        return new GridCharacterLibrary(directory, use_garbage);
    }

}; // namespace
