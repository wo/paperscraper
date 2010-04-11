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

    struct ScreenCharacter : ICharacter {
        bytearray m_image;                      // the character image
        int m_code;                             // the class label
        int m_xHeight;                          // the x-height
        strbuf description;                     // the description

        virtual ~ScreenCharacter() {}

        virtual bytearray &image() { return m_image;             }
        virtual int code()         { return m_code;              }
        virtual int xHeight()      { return m_xHeight;           }
        virtual const char *info() { return description; }
        virtual int baseline()     { return -1;                  }
        virtual int descender()    { return -1;                  }
        virtual int ascender()     { return -1;                  }
    };

    class ScreenCharacterLibrary : public ICharacterLibrary {
        objlist<ScreenCharacter> cur_char;       // current characters
        int current_section;                    // current section
        int first_section;                      // line of first section in directory
        int number_of_sections;                 // section count
        strbuf directory;                       // path to list file

        void load_section(int index) {
            ASSERT(index >= 0 && index < number_of_sections);
            FILE* f = fopen(directory,"r");
            ASSERT(f != NULL);

            // empty cur_char
            cur_char.clear();

            // browse forward till reaching first line that is not a comment
            char line[256];
            for(int i=0;i<=first_section;i++)
                fgets(line,sizeof line,f);

            // now parse lines and add chars with matching class label
            while(!feof(f)) {
                char buffer[256];
                strcpy(buffer,line);
                char* char_cls = strtok(line," ");
                for(int i=0;i<14;i++) char_cls = strtok(NULL," ");
                ASSERT(char_cls != NULL);

                if(atoi(char_cls) == index) {
                    ScreenCharacter &current = cur_char.push();
                    current.m_code = index;

                    //printf("line: %s\n",buffer);
                    char* png_filename = strtok(buffer," ");
                    //printf("p1: %s\n",png_filename);
                    png_filename = strtok(NULL," ");
                    //printf("p2: %s\n",png_filename);
                    ASSERT(png_filename != NULL);        

                    char* last_slash = strrchr(directory,'/');
                    ASSERT(last_slash != NULL);
                    size_t len_fn = strlen(last_slash);
                    size_t len_pt = strlen(directory);
                    char png_path[256];
                    strncpy(png_path,directory,len_pt-len_fn);
                    png_path[len_pt-len_fn] = '\0';
                    strcat(png_path,"/");
                    strcat(png_path,png_filename);
                    //printf("filepath: %s\n",png_path);
                    read_png(current.m_image,stdio(png_path,"r"),true);
                    //printf("IMAGE DEBUG\n");
                    //for(int i=0;i<current.m_image.length();i++) {
                    //    printf("img[%d] = %d\n",i,current.m_image(i));
                    //}

                    char* x_height = strtok(NULL," ");
                    for(int i=0;i<5;i++) x_height = strtok(NULL," ");
                    ASSERT(x_height != NULL);
                    current.m_xHeight = atoi(x_height);

                    char* desc = strtok(NULL," ");
                    for(int i=0;i<7;i++) desc = strtok(NULL," ");
                    ASSERT(desc != NULL);
                    current.description.ensure(strlen(desc)+1);
                    strcpy(current.description,desc);
                }

                fgets(line,sizeof line,f);
            }

            fclose(f);
        }

    public:
        virtual const char *description() {
            return "ScreenCharacterLibrary";
        }

        virtual void init(const char **argv) {}

        virtual int currentSectionIndex() {
            return current_section;
        }

        ScreenCharacterLibrary(const char *_directory) {
            directory.ensure(strlen(_directory)+1);
            strcpy(directory,_directory);
            FILE* f = fopen(directory,"r");
            ASSERT(f != NULL);

            char line[256];
            int counter = 0;
            bool comments = true;
            while(!feof(f)) {
                fgets(line,sizeof line,f);
                counter++;
                if(comments) {
                    if(strncmp(line,"//",2) != 0) {
                        first_section = counter;
                        comments = false;
                    }
                }
            }
            number_of_sections = 256;           // sections used as class labels here!
            fclose(f);

            switchToSection(0);
        }

        virtual ~ScreenCharacterLibrary() { }

        virtual int sectionsCount() {
            return number_of_sections;
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
            return cur_char.length();
        }

        virtual ICharacter &character(int index) {
            return cur_char[index];
        }
    };

    ICharacterLibrary *make_screenocr_charlib(const char *directory) {
        return new ScreenCharacterLibrary(directory);
    }

}; // end namespace ocropus
