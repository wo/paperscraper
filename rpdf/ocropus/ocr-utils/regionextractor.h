// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// 
// You may not use this file except under the terms of the accompanying license.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you
// may not use this file except in compliance with the License. You may
// obtain a copy of the License at http:  www.apache.org/licenses/LICENSE-2.0
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
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_regionextractor__
#define h_regionextractor__

#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "ocr-segmentations.h"

namespace ocropus {
    struct RegionExtractor {
        colib::intarray segmentation;
        colib::narray<colib::rectangle> boxes;
        void setImage(colib::intarray &image) {
            colib::intarray temp;
            copy(temp,image);
            imglib::renumber_labels(temp,1);
            imglib::bounding_boxes(boxes,temp);
        }
        void setImageMasked(colib::intarray &image,int mask,int lo,int hi) {
            makelike(segmentation,image);
            fill(segmentation,0);
            for(int i=0;i<image.length1d();i++) {
                int pixel = image.at1d(i);
                if(pixel<lo || pixel>hi) continue;
                segmentation.at1d(i) = (pixel & mask);
            }
            imglib::renumber_labels(segmentation,1);
            imglib::bounding_boxes(boxes,segmentation);
        }
        void setPageColumns(colib::intarray &image) {
            makelike(segmentation,image);
            fill(segmentation,0);
            for(int i=0;i<image.length1d();i++) {
                int pixel = image.at1d(i);
                int col = pseg_column(pixel);
                if(col<1||col>=32) continue;
                int par = pseg_paragraph(pixel);
                if(par>=64) continue;
                segmentation.at1d(i) = col;
            }
            imglib::renumber_labels(segmentation,1);
            imglib::bounding_boxes(boxes,segmentation);
        }
        void setPageParagraphs(colib::intarray &image) {
            makelike(segmentation,image);
            fill(segmentation,0);
            for(int i=0;i<image.length1d();i++) {
                int pixel = image.at1d(i);
                int col = pseg_column(pixel);
                if(col<1||col>=32) continue;
                int par = pseg_paragraph(pixel);
                if(par>=64) continue;
                segmentation.at1d(i) = (col<<8) | par;
            }
            imglib::renumber_labels(segmentation,1);
            imglib::bounding_boxes(boxes,segmentation);
        }
        void setPageLines(colib::intarray &image) {
            makelike(segmentation,image);
            fill(segmentation,0);
            for(int i=0;i<image.length1d();i++) {
                int pixel = image.at1d(i);
                int col = pseg_column(pixel);
                if(col<1||col>=32) continue;
                int par = pseg_paragraph(pixel);
                if(par>=64) continue;
                segmentation.at1d(i) = pixel;
            }
            imglib::renumber_labels(segmentation,1);
            imglib::bounding_boxes(boxes,segmentation);
        }
        int length() {
            return boxes.length();
        }
        colib::rectangle bbox(int i) {
            return boxes[i];
        }
        void bounds(int i,int *x0=0,int *y0=0,int *x1=0,int *y1=0) {
            *x0 = boxes[i].x0;
            *y0 = boxes[i].y0;
            *x1 = boxes[i].x1;
            *y1 = boxes[i].y1;
        }
        int x0(int i) {
            return boxes[i].x0;
        }
        int y0(int i) {
            return boxes[i].y0;
        }
        int x1(int i) {
            return boxes[i].x1;
        }
        int y1(int i) {
            return boxes[i].y1;
        }
        template <class S,class T>
        void extract(colib::narray<S> &output,colib::narray<T> &input,int index,int margin=0) {
            colib::rectangle r = boxes[index].grow(margin);
            r.intersect(colib::rectangle(0,0,input.dim(0),input.dim(1)));
            imglib::extract_subimage(output,input,r.x0,r.y0,r.x1,r.y1);
        }
        template <class S>
        void mask(colib::narray<S> &output,int index,int margin=0) {
            colib::rectangle r = boxes[index].grow(margin);
            r.intersect(colib::rectangle(0,0,segmentation.dim(0),segmentation.dim(1)));
            output.resize(r.x1-r.x0,r.y1-r.y0);
            fill(output,0);
            for(int i=r.x0;i<r.x1;i++) for(int j=r.y0;j<r.y1;j++) {
                if(segmentation(i,j)==index)
                    output(i-r.x0,j-r.y0) = 255;
            }
        }
    };
}

#endif
