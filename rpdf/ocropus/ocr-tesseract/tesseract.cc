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
// Project: ocr-tesseract
// File: tesseract.cc
// Purpose: interfaces to Tesseract
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#ifndef UNSAFE
#define ISOLATE_TESSERACT
#endif

#include <signal.h>
#include <string>  // otherwise `baseapi.h' will break CODE-OK--mezhirov

// Tess includes
#include "tordvars.h"
#include "control.h"
#include "tessvars.h"
#include "tessbox.h"
#include "tessedit.h"
#include "imgs.h"
#include "edgblob.h"
#include "makerow.h"
#include "wordseg.h"
#include "output.h"
#include "tstruct.h"
#include "tessout.h"
#include "tface.h"
#include "adaptmatch.h"
#include "baseapi.h"
#include "globals.h"

// these Tess-defined macros interfere with IUPR names
#undef rectangle
#undef min
#undef max

// IUPR includes
#include "tesseract.h"
#include "colib.h"
#include "imgio.h"
#include "io_png.h"
#include "imglib.h"
#include "imgops.h"
#include "ocr-utils.h"
#include "line-info.h"
#include "segmentation.h"
#include "ocr-segmentations.h"

using namespace colib;
using namespace imgio;
using namespace imglib;
using namespace ocropus;

namespace ocropus {
    param_string tesslanguage("tesslanguage", "eng", "Specify the language for Tesseract");
}

extern BOOL_VAR_H(textord_ocropus_mode, FALSE, "Make baselines for ocropus");

namespace {
    static int area(rectangle rect) {
        if (rect.width() <= 0 || rect.height() <= 0)
            return 0;
        return rect.width() * rect.height();
    }

    int arg_max_overlap(narray<rectangle> &line_boxes, rectangle char_box) {
        int best_so_far = -1;
        int best_overlap = -1;
        for(int i = 0; i < line_boxes.length(); i++) {
            int overlap = area(line_boxes[i].intersection(char_box));
            if(overlap > best_overlap) {
                best_so_far = i;
                best_overlap = overlap;
            }
        }
        return best_so_far;
    }

    void extract_bboxes(narray<rectangle> &result, RegionExtractor &e) {
        result.resize(max(e.length() - 1, 0));
        for(int i = 1; i < e.length(); i++)
            result[i-1] = rectangle(e.x0(i),e.y0(i),e.x1(i),e.y1(i));
    }
    
    /*static bool fits_into(rectangle inner, rectangle outer) {
        if (outer.empty())
            return false;
        if (inner.empty())
            return false;
        rectangle common = inner.intersection(outer);
        return 2 * area(common) > area(inner);
    }*/

#if 0
    // Given an output of SimpleOCR (string, costs, bboxes) and the segmentation,
    // produce a SegmentedOCR results (result, components).
    //
    // This uses heuristical match between bounding boxes returned by OCR and
    // the segmentation bounding boxes. That might fail, especially in the case
    // of undersegmentation.
    static void convert_results(IGenericFst &result,
                                idmap &components,
                                nustring &string,
                                floatarray &costs,
                                narray<rectangle> &bboxes,
                                intarray &segmentation) {
        check_line_segmentation(segmentation);
        make_line_segmentation_black(segmentation);
        set_line_number(segmentation, 0);
        components.clear();
        int n = string.length();
        ASSERT(costs.length() == n);
        ASSERT(bboxes.length() == n);

        narray<rectangle> seg_boxes;
        bounding_boxes(seg_boxes, segmentation);

        intarray ids(n);
        for(int i=0; i<n; i++) { 
            ids[i] = (string[i].ord() == ' '  ?  0  :  i + 1);
        }

        result.clear();
        result.setString(string, costs, ids);
        for(int i=0; i<n; i++) {
            // fill components
            for(int j=1; j<seg_boxes.length(); j++) {
                if(fits_into(seg_boxes[j], bboxes[i])) {
                    components.associate(ids[i], j);
                }
            }
        }
    }
#endif

    template<class T>
    void fill_rectangle(narray<T> &a, rectangle r, T value) {
        r.intersect(rectangle(0, 0, a.dim(0), a.dim(1)));
        for(int x = r.x0; x < r.x1; x++)
            for(int y = r.y0; y < r.y1; y++)
                a(x,y) = value;
    }

    // produce a crude segmentation by simply coloring bounding boxes
    void color_boxes(intarray &segmentation, rectarray &bboxes) {
        fill(segmentation, 0);
        for(int i = 0; i < bboxes.length(); i++)
            fill_rectangle(segmentation, bboxes[i], i + 1);
    }

    void fill_lattice(IGenericFst &lattice, nustring &text) {
        floatarray costs;
        intarray ids;
        makelike(costs, text);
        makelike(ids, text);
        for(int i = 0; i < text.length(); i++) {
            costs[i] = 1;
            ids[i] = i + 1;
        }
        lattice.setString(text, costs, ids);
    }
};


namespace ocropus {
    enum {MIN_HEIGHT = 30};

    class TesseractWrapper;
    TesseractWrapper *tesseract_singleton = NULL;


    void oops_tesseract_died(int signal) {
        fprintf(stderr, "ERROR: got signal from Tesseract (bug in Tesseract?)\n");
        exit(1);
    }

#ifdef ISOLATE_TESSERACT
    static bool inside_tesseract = false;
static struct sigaction SIGSEGV_old;
    static struct sigaction SIGFPE_old;
    static struct sigaction SIGABRT_old;
    static struct sigaction oops_sigaction;
#endif

    void enter_tesseract() {
#ifdef ISOLATE_TESSERACT
        ASSERT(!inside_tesseract);
        inside_tesseract = true;
        oops_sigaction.sa_handler = oops_tesseract_died;
        sigemptyset(&oops_sigaction.sa_mask);
        oops_sigaction.sa_flags = 0;
        sigaction(SIGSEGV, &oops_sigaction, &SIGSEGV_old);
        sigaction(SIGFPE,  &oops_sigaction, &SIGFPE_old);
        sigaction(SIGABRT, &oops_sigaction, &SIGABRT_old);
#endif
    }

    void leave_tesseract() {
#ifdef ISOLATE_TESSERACT
        ASSERT(inside_tesseract);
        sigaction(SIGSEGV, &SIGSEGV_old, NULL);
        sigaction(SIGFPE,  &SIGFPE_old, NULL);
        sigaction(SIGABRT, &SIGABRT_old, NULL);
        inside_tesseract = false;
#endif
    }




    ROW *tessy_make_ocrrow(float baseline, float xheight, float descender, float ascender) {
        int xstarts[] = {-32000};
        double quad_coeffs[] = {0,0,baseline};
        return new ROW(
            1,
            xstarts,
            quad_coeffs,
            xheight,
            ascender - (baseline + xheight),
            descender - baseline,
            0,
            0
            );
    }


// _______________________   getting Tesseract output   _______________________


/// Convert Tess rectangle to IUPR one
/// These (-1)s are strange; but they work on c_blobs' bboxes.
    /*rectangle tessy_rectangle(const BOX &b) {
        return rectangle(b.left() - 1, b.bottom() - 1, b.right() - 1, b.top() - 1);
    }*/


    static int counter = 0;
    inline double sqr(double x) {return x * x;}
    class TesseractWrapper : TessBaseAPI /* , public ISimpleLineOCR */{
        int pass;

        void pass_grayscale_image_to_tesseract(bytearray &image) {
            unsigned char *pixels = new unsigned char[image.length1d()];
            for(int x=0;x<image.dim(0);x++) for(int y=0;y<image.dim(1);y++)
                pixels[(image.dim(1) - y - 1) * image.dim(0) + x] = image(x,y);

            CopyImageToTesseract(pixels, 1, image.dim(0), 0, 0, image.dim(0), image.dim(1));

            delete [] pixels;
        }


        void extract_result_from_PAGE_RES(nustring &str,
                                          narray<rectangle> &bboxes,
                                          floatarray &costs,
                                          PAGE_RES &page_res) {
            char *string;
            int *lengths;
            float *tess_costs;
            int *x0;
            int *y0;
            int *x1;
            int *y1;
            int n = TesseractExtractResult(&string, &lengths, &tess_costs,
                                           &x0, &y0, &x1, &y1,
                                           &page_res);
            // now we'll have to cope with different multichar handling by us
            // and by Tesseract. All this is way too ugly and I hope it'll be
            // better eventually. I would vote for making nuchar doing what
            // nustring now does - I.M.
            int offset = 0;
            for(int i = 0; i < n; i++) {
                nustring multichar; // the multichar sequence of the glyph
                multichar.utf8Decode(string + offset, lengths[i]);
                offset += lengths[i];

                // copy bboxes for each subcomponent, split the cost
                for(int j = 0; j < multichar.length(); j++) {
                    str.push(multichar[j]);
                    rectangle &bbox = bboxes.push();
                    bbox.x0 = x0[i];
                    bbox.y0 = y0[i];
                    bbox.x1 = x1[i];
                    bbox.y1 = y1[i];
                    costs.push(tess_costs[i] / multichar.length());
                }
            }
            delete [] string;
            delete [] lengths;
            delete [] tess_costs;
            delete [] x0;
            delete [] y0;
            delete [] x1;
            delete [] y1;
        }

    public:
        void adapt(bytearray &image, int truth, float baseline, float xheight, float descender, float ascender) {
            pass_grayscale_image_to_tesseract(image);
            nustring text;
            text.push(nuchar(truth));
            char buf[20];
            text.utf8Encode(buf, sizeof(buf));
            if(!unicharset.contains_unichar(buf)) {
                //printf("Ouch! Character %s (%d) isn't known!\n", buf, truth);
                return;
            }
            AdaptToCharacter(buf, strlen(buf),
                             baseline, xheight, descender, ascender);
        }

        

        virtual const char *description() {
            return "a wrapper around Tesseract";
        }
        virtual void init(const char **argv=0) {
        }

        TesseractWrapper(const char *path_to_us) : pass(1) {
            if (!counter) {
                InitWithLanguage(path_to_us, NULL, tesslanguage, NULL, false, 0, NULL);

                // doesn't seem to do anything any longer
                //textord_ocropus_mode.set_value(true); 

                set_pass1();
            }
            counter++;
        }

        virtual ~TesseractWrapper() {
            counter--;
            ClearAdaptiveClassifier();
            if (!counter) {
                End();
            }
        }

        virtual void recognize_gray(nustring &result,
                                    floatarray &costs,
                                    narray<rectangle> &bboxes,
                                    bytearray &input_image) {
        
            enter_tesseract();
            bytearray image;
            copy(image, input_image);
            enum {PADDING = 3};
            pad_by(image, PADDING, PADDING, colib::byte(255));
            pass_grayscale_image_to_tesseract(image);
            BLOCK_LIST blocks;
            FindLines(&blocks);

        
            narray<autodel<WERD> > bln_words;

            // Recognize all words
            PAGE_RES page_res(&blocks);
            PAGE_RES_IT page_res_it(&page_res);
            while (page_res_it.word () != NULL) {
                WERD_RES *word = page_res_it.word();
                ROW *row = page_res_it.row()->row;

                matcher_pass = 0;
                WERD *bln_word = make_bln_copy(word->word, row, row->x_height(),
                                               &word->denorm);
                bln_words.push() = bln_word;
                BLOB_CHOICE_LIST_CLIST blob_choices;

                if (pass == 1) {
                    word->best_choice = tess_segment_pass1(bln_word, &word->denorm,
                                                            tess_default_matcher,
                                                            word->raw_choice, &blob_choices,
                                                            word->outword);
                } else {
                    word->best_choice = tess_segment_pass2(bln_word, &word->denorm,
                                                            tess_default_matcher,
                                                            word->raw_choice, &blob_choices,
                                                            word->outword);
                }

                //classify_word_pass1 (page_res_it.word(), page_res_it.row()->row, 
                //FALSE, NULL, NULL);

                page_res_it.forward();
            }
            extract_result_from_PAGE_RES(result, bboxes, costs, page_res);

            // Correct the padding.
            for(int i = 0; i < bboxes.length(); i++) {
                bboxes[i].x0 += -PADDING;
                bboxes[i].y0 += -PADDING;
                bboxes[i].x1 += -PADDING;
                bboxes[i].y1 += -PADDING;
            }
        
            /*for(int i = 0; i < result.length(); i++) {
              printf("%c %d %d %d %d\n", result[i],
              bboxes[i].x0, 
              input_image.dim(1) - bboxes[i].y0,
              bboxes[i].x1, 
              input_image.dim(1) - bboxes[i].y1);
              }*/
            leave_tesseract();
        }
    

        virtual void recognize_binary(nustring &result,floatarray &costs,narray<rectangle> &bboxes,bytearray &orig_image) {
            recognize_gray(result, costs, bboxes, orig_image);
        }

        virtual void start_training() {
            pass = 2;
        }
    
        virtual bool supports_char_training() {
            return true;
        }
    
        void train(nustring &chars,intarray &orig_csegmentation) {
            intarray csegmentation;
            copy(csegmentation, orig_csegmentation);
            check_line_segmentation(csegmentation);
            make_line_segmentation_black(csegmentation);
            check_line_segmentation(csegmentation,true);
            set_line_number(csegmentation, 0);
            int n = max(csegmentation);
            ALWAYS_ASSERT(chars.length() >= n);
            float intercept;
            float slope;
            float xheight;
            float ascender_rise;
            float descender_sink;
            bytearray line;
        
            if (!get_extended_line_info(intercept, slope, xheight,
                                        descender_sink, ascender_rise, csegmentation)) {
                return;
            }

            bytearray bitmap;
            for (int i = 0; i < n; i++) {
                set_pass1(); // because Tesseract adapts on pass 1
                makelike(bitmap, csegmentation);
                // int n = csegmentation.length1d();
                rectangle bbox(0,0,-1,-1);
                for (int x = 0; x < bitmap.dim(0); x++)
                    for (int y = 0; y < bitmap.dim(1); y++) {
                        if (csegmentation(x,y) == i + 1) {
                            bitmap(x,y) = 0;
                            bbox.include(x,y);
                        } else {
                            bitmap(x,y) = 255;
                        }
                    }

                // Checking whether bbox is non-empty is a kluge.
                // It might be empty in the case of undersegmentation.
                // In this case, due to recoloring, only one 
                // character will actually receive the segment.
                // Note that this situation probably suggests
                // that we'd better not train on this word.
                // But we still do. FIXME?
                if (bbox.width() > 0 && bbox.height() > 0)
                {
                    int center_x = (bbox.x0 + bbox.x1) / 2;
                    float baseline = intercept + center_x * slope ;
                    
                    adapt(bitmap, chars[i].ord(), baseline, xheight,
                          baseline - descender_sink,
                          baseline + xheight + ascender_rise);
                }
            }
        }
    
        virtual void train_binary_chars(nustring &chars,intarray &csegmentation) {
            enter_tesseract();
            train(chars, csegmentation);
            leave_tesseract();
        }


        virtual void train_gray_chars(nustring &chars,intarray &csegmentation,bytearray &image) {
            enter_tesseract();
            check_line_segmentation(csegmentation);
            intarray new_segmentation;
            copy(new_segmentation, csegmentation);
            binarize_in_segmentation(new_segmentation, image);
            check_line_segmentation(new_segmentation);
            train(chars, new_segmentation);
            leave_tesseract();
        }
    
        virtual bool supports_line_training() {
            return false;
        }
        virtual void train_binary(nustring &chars,bytearray &bimage) {
            throw "TesseractWrapper: linewise training is not supported";
        }
        virtual void train_gray(nustring &chars,bytearray &image) {
            throw "TesseractWrapper: linewise training is not supported";
        }

        // TODO: beautify
        void tesseract_recognize_blockwise(
            narray<rectangle> &zone_bboxes,
            narray<nustring> &text,
            narray<narray<rectangle> > &bboxes,
            narray<floatarray> &costs,
            bytearray &gray,
            intarray &pageseg) {

            RegionExtractor e;
            e.setPageColumns(pageseg);
            extract_bboxes(zone_bboxes, e);

            narray<BLOCK_LIST *> block_lists(e.length());
            narray<PAGE_RES *> block_results(e.length());
            fill(block_lists, static_cast<BLOCK_LIST *>(NULL));
            fill(block_results, static_cast<PAGE_RES *>(NULL));
            // pass 1
            for(int i = 1 /* RegionExtractor weirdness */; i < e.length(); i++) {
                bytearray block_image;
                if(gray.length1d()) {
                    e.extract(block_image, gray, i, /* margin: */ 1);
                    bytearray mask;
                    e.mask(mask, i, /* margin: */ 1);
                    make_background_white(block_image);
                    
                    bytearray dilated_mask;
                    copy(dilated_mask, mask);
                    dilate_circle(dilated_mask, 3);

                    ASSERT(samedims(mask, block_image));
                    ASSERT(samedims(dilated_mask, block_image));
                    for(int k = 0; k < block_image.length1d(); k++) {
                        if(!dilated_mask.at1d(k))
                            block_image.at1d(k) = 255;
                    }
                } else {
                    e.mask(block_image, i, /* margin: */ 1);
                    invert(block_image);
                }
                pass_grayscale_image_to_tesseract(block_image);
                block_lists[i-1] = TessBaseAPI::FindLinesCreateBlockList();
                block_results[i-1] = TessBaseAPI::RecognitionPass1(block_lists[i-1]);
            }
            
            int n = e.length() - 1;
            text.resize(n);
            bboxes.resize(n);
            costs.resize(n);

            // pass 2
            for(int i = 1 /* RegionExtractor weirdness */; i < e.length(); i++) {
                bytearray block_image;
                if(gray.length1d()) {
                    e.extract(block_image, gray, i, /* margin: */ 1);
                } else {
                    e.mask(block_image, i, /* margin: */ 1);
                    invert(block_image);
                }
                pass_grayscale_image_to_tesseract(block_image);
                block_results[i-1] = TessBaseAPI::RecognitionPass2(block_lists[i-1], block_results[i-1]);
                extract_result_from_PAGE_RES(text[i-1],
                                             bboxes[i-1],
                                             costs[i-1],
                                             *block_results[i-1]);
                DeleteBlockList(block_lists[i-1]);
            }
        }

        void tesseract_recognize_blockwise_and_split_to_lines(
                narray<nustring> &text,
                narray<narray<rectangle> > &bboxes,
                narray<floatarray> &costs,
                bytearray &gray,
                intarray &pseg) {

            // the output of tesseract_recognize_blockwise
            narray<rectangle> whole_zone_bboxes;
            narray<nustring> zone_text;
            narray<narray<rectangle> > zone_bboxes;
            narray<floatarray> zone_costs;

            RegionExtractor e;
            e.setPageLines(pseg);
            narray<rectangle> line_bboxes;
            extract_bboxes(line_bboxes, e);
            int nlines = max(e.length() - 1, 0);

            text.resize(nlines);
            bboxes.resize(nlines);
            costs.resize(nlines);

            narray<bool> pending_space(nlines);
            fill(pending_space, false);

            tesseract_recognize_blockwise(whole_zone_bboxes, zone_text,
                                          zone_bboxes, zone_costs, gray, pseg);

            for(int zone = 0; zone < whole_zone_bboxes.length(); zone++) {
                int line = -1;
                int nchars = zone_text[zone].length();
                for(int i = 0; i < nchars; i++) {
                    if(zone_text[zone][i].ord() == ' ') {
                        if(line != -1)
                            pending_space[line] = true;
                        continue;
                    }
                    rectangle abs_charbox = rectangle(
                        whole_zone_bboxes[zone].x0 + zone_bboxes[zone][i].x0,
                        whole_zone_bboxes[zone].y0 + zone_bboxes[zone][i].y0,
                        whole_zone_bboxes[zone].x0 + zone_bboxes[zone][i].x1,
                        whole_zone_bboxes[zone].y0 + zone_bboxes[zone][i].y1);
                    line = arg_max_overlap(line_bboxes, abs_charbox);
                    if(line == -1) continue;
                    if(pending_space[line]) {
                        text[line].push(nuchar(' '));
                        bboxes[line].push(abs_charbox);
                        costs[line].push(1000);
                        pending_space[line] = false;
                    }
                    text[line].push(zone_text[zone][i]);
                    bboxes[line].push(abs_charbox);
                    costs[line].push(zone_costs[zone][i]);
                }
            }
        }

    };

    void tesseract_recognize_blockwise_and_split_to_lines(
            narray<nustring> &text,
            narray<narray<rectangle> > &bboxes,
            narray<floatarray> &costs,
            bytearray &gray,
            intarray &pseg) {
        autodel<TesseractWrapper> tess(new TesseractWrapper(""));
        tess->tesseract_recognize_blockwise_and_split_to_lines(text, bboxes, costs, gray, pseg);
    }

    void tesseract_recognize_blockwise_and_dump(bytearray &gray,
                                                intarray &pageseg) {
        autodel<TesseractWrapper> tess(new TesseractWrapper(""));
        //narray<rectangle> zone_boxes;
        narray<nustring> text;
        narray<narray<rectangle> > bboxes;
        narray<floatarray> costs;

        tess->tesseract_recognize_blockwise_and_split_to_lines(text, bboxes, costs, gray, pageseg);
        for(int zone = 0; zone < text.length(); zone++) {
            char *s = text[zone].newUtf8Encode();
            printf("[zone %d] %s\n", zone + 1, s);
            delete[] s;
        }
    }

    struct TesseractRecognizeLine : IRecognizeLine {
        autodel<TesseractWrapper> tess;
        bool training;

        const char *description() {
            return "Tesseract Wrapper";
        }

        TesseractRecognizeLine() {
            tess = new TesseractWrapper("");
            training = false;
        }

        virtual void recognizeLine(IGenericFst &result,bytearray &image) {
            nustring text;
            floatarray costs;
            rectarray bboxes;
            tess->recognize_gray(text, costs, bboxes, image);
            fill_lattice(result, text);
        }

        virtual void recognizeLine(intarray &segmentation,IGenericFst &result,bytearray &image) { 
            nustring text;
            floatarray costs;
            rectarray bboxes;
            tess->recognize_gray(text, costs, bboxes, image);
            fill_lattice(result, text);
            makelike(segmentation, image);
            color_boxes(segmentation, bboxes);
            // crude binarization (FIXME?) ...
            bytearray binarized;
            binarize_simple(binarized, image);
            make_background_white(binarized);
            for(int i = 0; i < segmentation.length1d(); i++) {
                if(binarized.at1d(i))
                    segmentation.at1d(i) = 0;
            }
        }
    };



    IRecognizeLine *make_TesseractRecognizeLine() {
        return new TesseractRecognizeLine();
    }
}
namespace {
    rectangle unite_rectangles(narray<rectangle> &rects) {
        rectangle result;
        for(int i = 0; i < rects.length(); i++) {
            result.include(rects[i]);
        }
        return result;
    }
}
namespace ocropus {
    void tesseract_recognize_blockwise(RecognizedPage &result, colib::bytearray &gray, colib::intarray &pageseg) {
        //double start = now();
        narray<nustring> text;
        narray<narray<rectangle> > bboxes;
        narray<floatarray> costs;
        tesseract_recognize_blockwise_and_split_to_lines(text, bboxes, costs, gray, pageseg);
        result.setWidth(gray.dim(0));
        result.setHeight(gray.dim(1));
        result.setLinesCount(text.length());
        for(int i = 0; i < text.length(); i++) {
            result.setText(text[i], i);
            result.setBbox(unite_rectangles(bboxes[i]), i);
            result.setCosts(costs[i], i);
        }
        // description
        // Time report        
    }
    void tesseract_init_with_language(const char *language) {
        TessBaseAPI::InitWithLanguage(0,0,language,0,false,0,0);
    }

    char *tesseract_rectangle(bytearray &image,int x0,int y0,int x1,int y1) {
        bytearray temp;
        ASSERT(0 <= x0);
        ASSERT(x0 < x1);
        ASSERT(x1 <= image.dim(0));
        ASSERT(0 <= y0);
        ASSERT(y0 < y1);
        ASSERT(y1 <= image.dim(1));
        math2raster(temp,image);
        char *text = TessBaseAPI::TesseractRect(&temp(0,0),1,temp.dim(1),x0,y0,x1,y1);
        return text;
    }

    char *tesseract_block(bytearray &image) {
        return tesseract_rectangle(image,0,0,image.dim(0),image.dim(1));
    }

    void tesseract_end() {
        TessBaseAPI::End();
    }

}
