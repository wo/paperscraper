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
// File: lines.h
// Purpose: 
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#ifndef h_lines_
#define h_lines_

#include "ocrinterfaces.h"
#include "pages.h"

namespace ocropus {

    // This interface provides line-level access to the pages.
    // Apart from encapsulating Pages, ISegmentPage and RegionExtractor,
    // it will also (in the near future) help in building color-coded
    // segmentations by collecting line segmentations, putting them onto a page
    // and undoing any coordinate-changing transformations (deskewing)
    // that it might have made.
    
    /// A collection of lines.
    struct ILines : colib::IComponent {
        /// Get the total number of pages.
        virtual int pagesCount() = 0;

        /// Switch to page with the given index.
        /// This is called processPage() rather then getPage() to indicate that it takes a long time.
        virtual void processPage(int index) = 0;
        
        virtual int pageWidth() = 0;
        virtual int pageHeight() = 0;
        virtual const char *pageDescription() = 0;

        /// Get time (in seconds) used to preprocess and to analyze the layout on all the pages.
        virtual double getTotalElapsedTime() = 0;

        /// Get time (in seconds) used to preprocess and to analyze the layout on the current page.
        virtual double getCurrentPageElapsedTime() = 0;

        /// Return the number of lines in the current page.
        virtual int linesCount() = 0;

        /// Return the grayscale image and a white-on-black mask (binarized version) of the line.
        virtual void line(colib::bytearray &result_image,
                          colib::bytearray &result_mask, 
                          int index) = 0;

        /// Return the index of a column that the line belongs to.
        virtual int columnIndex(int line) = 0;

        /// Return the index of a paragraph that the line belongs to.
        virtual int paragraphIndex(int line) = 0;

        /// Return the bounding box of the line on the page.
        /// FIXME: doesn't work with a deskewer (gives the deskewed coordinates)
        virtual colib::rectangle bbox(int index) = 0;

        virtual colib::bytearray &grayPage() = 0;
        inline void grayPage(colib::bytearray &r) {colib::copy(r, grayPage());}
        virtual colib::bytearray &binaryPage() = 0;
        inline void binaryPage(colib::bytearray &r) {
            colib::copy(r, binaryPage());
        }
        virtual colib::intarray &segmentation() = 0;
        inline void segmentation(colib::intarray &r) {
            colib::copy(r, segmentation());
        }

        virtual void setBinarizer     (colib::IBinarize      *) = 0;
        virtual void setDeskewer      (colib::ICleanupGray   *) = 0;
        virtual void addCleanupGray   (colib::ICleanupGray   *) = 0;
        virtual void addCleanupBinary (colib::ICleanupBinary *) = 0;
        virtual void setPageSegmenter (colib::ISegmentPage   *) = 0;
    };

    ILines *make_Lines(Pages *);
    ILines *make_Lines(const char *page_specs);

}

#endif
