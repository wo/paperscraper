// Copyright 2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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
// File: lines.cc
// Purpose: 
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include "lines.h"
#include "pages.h"
#include "ocr-segmentations.h"
#include "regionextractor.h"
#include "imglib.h"
#include "ocr-utils.h"
#include "logger.h"

using namespace colib;
using namespace imgio;
using namespace imglib;
using namespace ocropus;

namespace {
    Logger log_main("lines");

    // Observe the mapping between `from' and `to' and return its inverse.
    // This function is just a complement to renumber_labels (and probably
    // renumber_labels should be rewritten to support this thing).
    // FIXME: some optimization?
    // FIXME: anyway, better to hack imglib instead
    void learn_backmapping(intarray &result, intarray &from, intarray &to) {
        CHECK_ARG(samedims(from, to));
        int n = max(to);
        result.resize(n + 1);
        fill(result, 0);
        for(int i = 0; i < to.length1d(); i++)
            result[to.at1d(i)] = from.at1d(i);
    }

    struct Lines : ILines {
        // this binarizer overrides pages->binarizer
        // must be set if deskewer is present
        autodel<IBinarize> binarizer;

        autodel<Pages> pages;
        RegionExtractor region_extractor;
        autodel<ICleanupGray> deskewer;
        narray< autodel<ICleanupGray> > cleanups_gray;
        narray< autodel<ICleanupBinary> > cleanups_binary;
        autodel<ISegmentPage> segmenter;
        rectarray bboxes;
        double elapsed;
        double last_elapsed;
        bytearray gray; // cleaned version of pages->getGray()
        intarray seg; // page segmentation
        bytearray binary;
        intarray ids;
        int page_width;
        int page_height;
        
        Lines(Pages *p) : pages(p), elapsed(0), last_elapsed(0) {}
        
        /// Get the total number of pages.
        int pagesCount() {
            return pages->length();
        }

        void deskewIfNeeded(bytearray &gray, bytearray &binary) {
            if(!!deskewer) {
                bytearray in;
                pages->getGray(in);
                make_background_white(in);
                deskewer->cleanup(gray, in);
                if(!binarizer)
                    throw "Lines: deskewer requires binarizer to be in Lines";
                binarizer->binarize(binary, gray);
            } else {
                pages->getGray(gray);
                make_background_white(gray);
                if(!binarizer) {
                    pages->getBinary(binary);
                    make_background_white(binary);
                } else {
                    binarizer->binarize(binary, gray);
                }
            }
        }

        int pageWidth() {return page_width;}
        int pageHeight() {return page_height;}
        
        /// Switch to page with the given index.
        /// This is called processPage() rather then getPage()
        /// to indicate that it might take a long time.
        void processPage(int index) {
            log_main.format("processPage(%d)", index);
            pages->getPage(index);

            double start = now();

            deskewIfNeeded(gray, binary);
            for(int i = 0; i < cleanups_gray.length(); i++) {
                bytearray tmp;
                cleanups_gray[i]->cleanup(tmp, gray);
                copy(gray, tmp);
            }
            for(int i = 0; i < cleanups_binary.length(); i++) {
                bytearray tmp;
                cleanups_binary[i]->cleanup(tmp, binary);
                copy(binary, tmp);
            }
            segmenter->segment(seg, binary);
            region_extractor.setPageLines(seg);

            // FIXME: region_extractor.segmentation probably shouldn't be used
            // directly
            learn_backmapping(ids, seg, region_extractor.segmentation);

            double end = now();
            last_elapsed = end - start;
            elapsed += last_elapsed;
            
            page_width = pages->getGray().dim(0);
            page_height = pages->getGray().dim(1);
        }
        
        /// Get time (in seconds) used to preprocess and to analyze the layout on all the pages.
        double getTotalElapsedTime() {
            return elapsed;
        }

        /// Get time (in seconds) used to preprocess and to analyze the layout on the current page.
        double getCurrentPageElapsedTime() {
            return last_elapsed;
        }
        
        /// Return the number of lines in the current page.
        int linesCount() {
            return max(region_extractor.length() - 1, 0);
        }
        
        /// Return the grayscale image and a white-on-black mask for the line.
        void line(bytearray &result_image, bytearray &result_mask, int index) {
            region_extractor.extract(result_image, gray, index + 1, 2);
            region_extractor.mask(result_mask, index + 1, 2);
            log_main("Lines::line() returning line image", result_image);
            log_main("Lines::line() returning line mask", result_mask);
        }
        
        /// Return the index of a column that the line belongs to.
        int columnIndex(int line) {
            return pseg_column(ids[line]);
        }

        int paragraphIndex(int line) {
            return pseg_paragraph(ids[line]);
        }
        
        const char *pageDescription() {
            return pages->getFileName();
        }

        /// Return the bounding box of the line on the page.
        rectangle bbox(int index) {
            return region_extractor.boxes[index + 1];
        }

        virtual void setBinarizer(colib::IBinarize *ptr) {
            binarizer = ptr;
        }
        
        virtual void setDeskewer(colib::ICleanupGray *ptr) {
            deskewer = ptr;
        }
        
        virtual void addCleanupGray(colib::ICleanupGray *ptr) {
            cleanups_gray.push() = ptr;
        }
        
        virtual void addCleanupBinary(colib::ICleanupBinary *ptr) {
            cleanups_binary.push() = ptr;
        }
        
        virtual colib::bytearray &grayPage() {
            return gray;
        }

        virtual colib::bytearray &binaryPage() {
            return binary;
        }
        
        virtual colib::intarray &segmentation() {
            return seg;
        }
        
        virtual void setPageSegmenter(colib::ISegmentPage *ptr) {
            segmenter = ptr;
        }
        virtual const char *description() {
            return "Lines";
        }
    };
}

namespace ocropus {
    ILines *make_Lines(Pages *pages) {
        return new Lines(pages);
    }
    
    ILines *make_Lines(const char *spec) {
        Pages *pages = new Pages();
        pages->parseSpec(spec);
        return make_Lines(pages);
    }
}
