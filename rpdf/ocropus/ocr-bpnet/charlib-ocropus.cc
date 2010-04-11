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
#include "imglib.h"
#include "imgio.h"
#include "charlib.h"
#include "narray-io.h"

using namespace imgio;
using namespace imglib;
using namespace colib;

namespace ocropus {

    static void read_transcript(narray<nustring> &text,
                                narray<rectangle> &boxes, FILE *f) {
        // FIXME this is some oddball binary file format; please make this
        // a UTF-8 encoded file
        int n = read_int32(f);
        text.resize(n);
        boxes.resize(n);
        for(int i = 0; i < n; i++) {
            bin_read(boxes[i], f);
            bin_read_nustring(f,text[i]);
        }
    }

    struct OcropusGeneratedCharacter : ICharacter {
        bytearray m_image;
        strbuf description;
        int m_code;

        virtual bytearray &image() { return m_image; }
        virtual int code()         { return m_code;  }
        virtual int xHeight()      { return 0; }
        virtual int baseline()     { return 0; }
        virtual int ascender()     { return 0; }
        virtual int descender()    { return 0; }
        virtual const char *info() { return (char*)description; }
    };

    static void remove_line_no(intarray &result, intarray &line, int n) {
        makelike(result, line);
        fill(result, 0);
        for(int i = 0; i < line.length1d(); i++) {
            if(line.at1d(i)>>12 == n)
                result.at1d(i) = line.at1d(i) & 0xFFF;
        }
    }

    /// Extract the set of pixels with the given value and return it
    /// as a black-on-white image.
    static void extract_segment(bytearray &result, intarray &image, int n) {
        makelike(result, image);
        fill(result, 255);
        for(int i = 0; i < image.length1d(); i++) {
            if(image.at1d(i) == n)
                result.at1d(i) = 0;
        }
    }


    // Fills a narray<OcropusGeneratedCharacter> from a line and its transcript.
    static void fill_section(narray<OcropusGeneratedCharacter> &section,
                             intarray &line,
                             nustring &transcript) {
        narray<rectangle> bboxes;
        bounding_boxes(bboxes, line);
        section.resize(min(transcript.length(), bboxes.length()));
        for(int i = 0; i < section.length(); i++) {
            if(i >= bboxes.length()) break;
            intarray subimage;
            rectangle &b = bboxes[i + 1];
            extract_subimage(subimage, line, b.x0, b.y0, b.x1, b.y1);
            extract_segment(section[i].m_image, subimage, i + 1);
            section[i].description.ensure(200);
            strcpy(section[i].description,"");
            section[i].m_code = transcript[i].ord();
        }
    }

    struct OcropusGeneratedCharlib : ICharacterLibrary {
        int current_section;
        narray< narray<OcropusGeneratedCharacter> > sections;

        virtual const char *description() {
            return "OcropusGeneratedCharlib";
        }

        virtual void init(const char **argv) {
        }

        virtual int currentSectionIndex() {
            return current_section;
        }

        virtual int sectionsCount() {
            return sections.length();
        }

        virtual void switchToSection(int index) {
            current_section = index;
        }

        virtual int charactersCount() {
            return sections[current_section].length();
        }

        virtual ICharacter &character(int index) {
            ASSERT(index >= 0  &&  index < charactersCount());
            return sections[current_section][index];
        }

        OcropusGeneratedCharlib(const char *path_prefix) {
            narray<nustring> transcript;
            narray<rectangle> bboxes;
            strbuf path1,path2;
            path1.ensure(strlen(path_prefix)+strlen(".ocr.dat")+1);
            path2.ensure(strlen(path_prefix)+strlen(".seg.png")+1);
            strcpy(path1,path_prefix);
            strcpy(path2,path_prefix);
            strcat(path1,".ocr.dat");
            strcat(path2,".seg.png");
            read_transcript(transcript, bboxes,stdio((const char*)(path1), "rb"));
            intarray seg;
            read_png_rgb(seg, stdio((const char*)(path2), "rb"));
            sections.resize(transcript.length());
            for(int i = 0; i < sections.length(); i++) {
                intarray cropped_line;
                extract_subimage(cropped_line, seg, bboxes[i].x0, bboxes[i].y0, bboxes[i].x1, bboxes[i].y1);
                intarray line;
                remove_line_no(line, cropped_line, i + 1);
                fill_section(sections[i], line, transcript[i]);
            }
        }
    };

    ICharacterLibrary *make_ocropus_charlib(const char *prefix) {
        return new OcropusGeneratedCharlib(prefix);
    }

};
