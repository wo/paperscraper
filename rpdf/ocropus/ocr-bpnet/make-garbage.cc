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
// Project: ocr-bpnet - neural network classifier
// File: make-garbage.cc
// Purpose: producing garbage (wrongly segmented) characters from ground truth
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de


#include "colib.h"
#include "imglib.h"
#include "imgio.h"
#include "ocr-utils.h"
#include "segmentation.h"
#include "line-info.h"
#include "ocr-segmentations.h"
#include "grid.h"
#include "grouper.h"

using namespace colib;
using namespace imglib;
using namespace imgio;
using namespace ocropus;

namespace {

    enum {MAX_PIX_DIFF = 7};

    colib::vec2 get_mass_center(const bytearray &image) {
        double sx = 0;
        double sy = 0;
        double mass = 0;
        int w = image.dim(0);
        int h = image.dim(1);

        for (int x = 0; x < w; x++) {
            for (int y = 0; y < h; y++) {
                byte m = 255 - image(x, y);
                sx += x * m;
                sy += y * m;
                mass += m;
            }
        }
        
        colib::vec2 center;
        center[0] = float(sx / mass);
        center[1] = float(sy / mass);

        return center;
    }


    double black_pixel_diff_one_way(bytearray &img1, colib::vec2 center1,
                                    bytearray &img2, colib::vec2 center2) {

        double penalty = 0;
        colib::vec2 shift = center2 - center1;
        int shift_x = int(floor(shift(0) + .5));
        int shift_y = int(floor(shift(1) + .5));
        for(int x1 = 0; x1 < img1.dim(0); x1++)
        for(int y1 = 0; y1 < img1.dim(1); y1++)
        {
            if (img1(x1, y1))
                continue;

            int x2 = x1 + shift_x;
            int y2 = y1 + shift_y;
            if (x2 < 0 || y2 < 0 || x2 >= img2.dim(0) || y2 >= img2.dim(1))
                penalty += 255;
            else
                penalty += img2(x2, y2);
        }
        return penalty;
    }


    double black_pixel_diff(bytearray &img1, colib::vec2 center1,
                            bytearray &img2, colib::vec2 center2) {
        return black_pixel_diff_one_way(img1, center1, img2, center2)
             + black_pixel_diff_one_way(img2, center2, img1, center1);
    }


    double black_pixel_diff(bytearray &img1, bytearray &img2) {
        return black_pixel_diff(img1, get_mass_center(img1),
                                img2, get_mass_center(img2));
    }


    bool match(bytearray &image1, bytearray &image2) {
        return black_pixel_diff(image1, image2) <= 255 * MAX_PIX_DIFF;
    }


    bool has_match(objlist<bytearray> &image_set, bytearray &image) {
        for(int i = 0; i < image_set.length(); i++) {
            if(match(image_set[i], image))
                return true;
        }
        return false;
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


    void extract_components(objlist<bytearray> &components,
                            intarray &black_seg) {
        narray<rectangle> bboxes;
        bounding_boxes(bboxes, black_seg);
        components.resize(bboxes.length() - 1);
        for(int i = 0; i < components.length(); i++) {
            intarray subimage;
            rectangle &b = bboxes[i + 1];
            extract_subimage(subimage, black_seg, b.x0, b.y0, b.x1, b.y1);
            extract_segment(components[i], subimage, i + 1);
        }
    }

    void make_garbage_given_true_chars(narray<rectangle> &bboxes,
                                       objlist<bytearray> &garbage,
                                       objlist<bytearray> &truth_images,
                                       intarray &oversegmented_line) {
        autodel<IGrouper> grouper(make_StandardGrouper());
        grouper->setSegmentation(oversegmented_line);
        bytearray binary_line;
        make_line_segmentation_white(oversegmented_line);
        forget_segmentation(binary_line, oversegmented_line);
        
        int n = grouper->length();
        for(int i = 0; i < n; i++) {
            bytearray component;
            bytearray mask;
            grouper->extract(component, mask, binary_line, i);
            invert(mask);
            if(!has_match(truth_images, mask)) {
                bboxes.push(grouper->boundingBox(i));
                move(garbage.push(), mask);
            }
        }
    }

}

namespace ocropus {

    void make_garbage(narray<rectangle> &bboxes,
                      narray<bytearray> &result_garbage,
                      intarray &orig_segmented_line,
                      ISegmentLine &segmenter) {
        objlist<bytearray> garbage;
        intarray segmented_line;
        copy(segmented_line, orig_segmented_line);
        make_line_segmentation_black(segmented_line);
        
        bytearray binary_line;
        forget_segmentation(binary_line, segmented_line);
        intarray oversegmented_line;
        segmenter.charseg(oversegmented_line, binary_line);
        make_line_segmentation_black(oversegmented_line);

        objlist<bytearray> truth_images;
        extract_components(truth_images, segmented_line);
        make_garbage_given_true_chars(bboxes, garbage, truth_images,
                                      oversegmented_line);
        result_garbage.resize(garbage.length());
        for(int i = 0; i < garbage.length(); i++)
            move(result_garbage[i], garbage[i]);
    }
    
    void make_garbage(narray<rectangle> &bboxes,
                      narray<bytearray> &result_garbage,
                      intarray &orig_segmented_line) {
        autodel<ISegmentLine> segmenter(make_CurvedCutSegmenter());
        make_garbage(bboxes, result_garbage, orig_segmented_line, *segmenter);
    }
}
