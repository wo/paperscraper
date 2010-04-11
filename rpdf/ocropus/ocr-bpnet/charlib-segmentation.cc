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
#include "ocr-utils.h"
#include "narray-io.h"
#include "charlib.h"
#include "classmap.h"
#include "line-info.h"
#include "make-garbage.h"

using namespace imgio;
using namespace imglib;
using namespace colib;

namespace ocropus {

    struct SegmentationCharacter : ICharacter {
        bytearray m_image;
        int m_code;
        int m_xHeight;
        int m_baseline;
        int m_ascender;
        int m_descender;
        strbuf description;

        virtual ~SegmentationCharacter() {}

        virtual bytearray &image() { return m_image;     }
        virtual int code()         { return m_code;      }
        virtual int xHeight()      { return m_xHeight;   }
        virtual int baseline()     { return m_baseline;  }
        virtual int ascender()     { return m_ascender;  }
        virtual int descender()    { return m_descender; }
        virtual const char *info() { return description; }
    };


    /// Extract subimages of a color coded segmentation
    static void extract_subimages(objlist<bytearray> &subimages,narray<rectangle> &bboxes,intarray &segmentation) {
        subimages.clear();
        bounding_boxes(bboxes,segmentation);
        for(int i=1;i<bboxes.length();i++) {
            intarray segment;
            rectangle &b = bboxes[i];
            extract_subimage(segment,segmentation,b.x0,b.y0,b.x1,b.y1);
            bytearray subimage;
            extract_segment(subimage,segment,i);
            copy(subimages.push(),subimage);
        }
        for(int i = 0; i < bboxes.length() - 1; i++) {
            bboxes[i] = bboxes[i + 1];
        }
        bboxes.resize(bboxes.length() - 1);
    }

    struct SegmentationCharlib : ICharacterLibrary {
        int current_section;
        objlist<SegmentationCharacter> characters;
        int ascender, descender, xHeight, baseline;
        int line_count;
        // we have either...
        objlist<strbuf> file_list;
        // ... or a pair (image, text)
        strbuf segmentation_file;
        strbuf transcript_file;
        bool produce_garbage;

        virtual const char *description() {
            return "SegmentationCharlib";
        }

        virtual void init(const char **argv) {
        }

        virtual int currentSectionIndex() {
            return current_section;
        }

        virtual int sectionsCount() {
            return max(file_list.length(), 1);
        }

        virtual void switchToSection(int index) {
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

        void provide_line_info(narray<rectangle> &bboxes,
                               intarray &segmentation) {
            ASSERT(bboxes.length() == characters.length());
            float intercept;
            float slope;
            float xheight;
            float descender_sink;
            float ascender_rise;
            float baseline;
            float descender;
            float ascender;
            if(!get_extended_line_info(intercept,slope,xheight,
                                       descender_sink,ascender_rise,
                                       segmentation)) {
                intercept = 0;
                slope = 0;
                xheight = 0;
                descender_sink = 0;
                ascender_rise = 0;
                baseline = 0;
                descender = 0;
                ascender = 0;
            }
            xheight = estimate_xheight(segmentation,slope);
            
            for(int i=0;i<bboxes.length();i++) {
                baseline = intercept+bboxes[i].x0 * slope;
                ascender = baseline+xheight+descender_sink;
                descender = baseline-descender_sink;

                SegmentationCharacter &c = characters[i];
                c.m_descender = int(descender+0.5);
                c.m_baseline = int(baseline+0.5);
                c.m_xHeight = int(xheight+0.5);
                c.m_ascender = int(ascender+0.5);
            }            
        }

        // Fills a section of a narray<SegmentationCharacter> from a line and its transcript.
        void load_section(int index) {
            if(file_list.length()) {
                segmentation_file = file_list[index];
                transcript_file = file_list[index];
                segmentation_file += ".png";
                segmentation_file += ".txt";
            }
            intarray segmentation;
            objlist<bytearray> subimages;
            narray<rectangle> bboxes;

            // extract subimages
            read_png_rgb(segmentation,stdio(segmentation_file,"rb"));
            replace_values(segmentation, 0xFFFFFF, 0);
            extract_subimages(subimages,bboxes,segmentation);

            // read transcript
            char trans[1000];
            fgets(trans,256,stdio(transcript_file,"r"));
            nustring transcript(trans);
            
            // check if OK
            if(subimages.length()!=transcript.length()) {
                characters.clear(); 
                return;
            }

            ASSERT(subimages.length() == bboxes.length());

            // make some garbage
            if(produce_garbage) {
                narray<rectangle> garbage_bboxes;
                narray<bytearray> garbage_images;
                make_garbage(garbage_bboxes, garbage_images, segmentation);
                ASSERT(samedims(garbage_bboxes, garbage_images));
                for(int i = 0; i < garbage_bboxes.length(); i++) {
                    bboxes.push(garbage_bboxes[i]);
                    move(subimages.push(), garbage_images[i]);
                    transcript.push(nuchar(0xAC));
                }
            }

            ASSERT(subimages.length() == bboxes.length());
            ASSERT(subimages.length() == transcript.length());

            // fill section
            characters.resize(subimages.length());      
            for(int i=0;i<subimages.length();i++) {
                SegmentationCharacter &c = characters[i];
                copy(c.m_image,subimages[i]);
                c.description.ensure(strlen(segmentation_file)+1);
                strcpy(c.description,&*segmentation_file);
                c.m_code = transcript(i).ord();
            }

            provide_line_info(bboxes, segmentation);
        }

        SegmentationCharlib(const char *path_file_list,
                            bool _produce_garbage) {
            produce_garbage = _produce_garbage;
            stdio file_list_fp = stdio(path_file_list,"r");
            while(1) {
                char path[1000];
                if(fscanf(file_list_fp,"%s", path) != 1)
                    break;
                file_list.push() = path;
            }
            switchToSection(0);
        }
        
        SegmentationCharlib(const char *image_path,
                            const char *text_path,
                            bool _produce_garbage) {
            produce_garbage = _produce_garbage;
            segmentation_file = image_path;
            transcript_file = text_path;
            switchToSection(0);
        }
    };

    ICharacterLibrary *make_SegmentationCharlib(const char *path_file_list,
                                                bool produce_garbage) {
        return new SegmentationCharlib(path_file_list, produce_garbage);
    }
    
    ICharacterLibrary *make_SegmentationCharlib(const char *image_path,
                                                const char *text_path,
                                                bool produce_garbage) {
        return new SegmentationCharlib(image_path,
                                       text_path,
                                       produce_garbage);
    }

};
