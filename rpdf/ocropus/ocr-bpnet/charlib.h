// -*- C++ -*-

// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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
// Project: ocr-extract-features -- feature extraction
// File: charlib.h
// Purpose: defining an abstract character dataset
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_charlib_
#define h_charlib_

#include "ocrinterfaces.h"
#include "logger.h"

namespace ocropus {

    enum {
        /// This is a special code used for garbage (incorrectly segmented characters or noise).
        /// The garbage predictions will be simply removed from the NN output; but it might be
        /// useful to train on those.
        GARBAGE = 0xAC
    };

    struct ICharacter {
        virtual ~ICharacter() {};

        /// Returns a reference to the current image.
        /// Probably should be deprecated in favor of get_image().
        virtual colib::bytearray &image() = 0;

        /// This should become the replacement for image().
        inline void get_image(colib::bytearray &result) {
            copy(result, image());
        }
        virtual int code() = 0;
        virtual int xHeight() = 0;
        virtual int baseline() = 0;
        virtual int descender() = 0;
        virtual int ascender() = 0;
        virtual const char *info() = 0; /// some line that can help locate it in the database
    };


    /// A character library consists of a bunch of sections.
    /// Only one section may be active at a time.
    /// Every section is a bunch of characters.
    /// Switching between sections is potentially time-consuming,
    /// but once a section is loaded ("switched to"),
    /// characters are accessed quickly.
    ///
    struct ICharacterLibrary : colib::IComponent {
        virtual int sectionsCount() = 0;

        virtual void switchToSection(int no) = 0;
        virtual int currentSectionIndex() = 0;

        /// Returns the number of characters in the current section.
        /// Sections cannot be empty.
        virtual int charactersCount() = 0;

        /// The returned reference is only valid till next switching.
        virtual ICharacter &character(int index) = 0;
    };


    /// Make a slice of existing library. Two indices given here are indices of sections.
    ICharacterLibrary *make_slice_charlib(ICharacterLibrary &charlib, int from_incl, int upto_excl);

    /// Join some characters like O and 0. This is for evaluation only.
    ICharacterLibrary *make_filter_charlib(ICharacterLibrary &charlib);

    /// Make a CharacterLibrary that reads grid files.
    ICharacterLibrary *make_grid_charlib(const char *directory, bool use_garbage = true);

    /// Make a CharacterLibrary from UW3 character data. The given directory should contain
    /// GROUND and IMAGEBIN subdirectories. There are two such directories in UW3:
    /// /ENGLISH/CHAR_TRU/SYNTHET and /ENGLISH/CHAR_TRU/REAL.
    ICharacterLibrary *make_uw3_charlib(const char *directory, const char *picture_suffix);

    /// Make a charlib whereby directory is the path to a file listing screen ocr pics.
    /// list file similar to /data/datasets/screen-text/extracted-screen-chars/extracted-images/screen-chars.txt
    ICharacterLibrary *make_screenocr_charlib(const char *directory);

    /// Make a CharacterLibrary from a file containing "<character> <png file name>" pairs.
    ICharacterLibrary *make_pnglist_charlib(const char *list);

    /// Make a CharacterLibrary from a ocropus-generated pair of files (obsolete).
    ICharacterLibrary *make_ocropus_charlib(const char *prefix);

    /// Make a CharacterLibrary from a list of (segmentation, transcript) pairs.
    ICharacterLibrary *make_SegmentationCharlib(const char *path_file_list,
                                                bool produce_garbage = true);
    
    /// Make a CharacterLibrary from a forced-alignment-generated pair of files.
    ICharacterLibrary *make_SegmentationCharlib(const char *image_path,
                                                const char *text_path,
                                                bool produce_garbage = true);

    void dump_charlib(Logger &log, ICharacterLibrary &);

}; // namespace

#endif
