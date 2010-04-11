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
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include <stdio.h>
#include "grouper.h"
#include "imglib.h"
#include "imgio.h"
#include "ocr-utils.h"
#include "ocr-segmentations.h"

using namespace imglib;
using namespace colib;

namespace ocropus {
    void sort_by_xcenter(intarray &labels) {
        make_line_segmentation_black(labels);
        floatarray centers;
        intarray counts;
        int n = max(labels)+1;
        ASSERT(n<10000);
        centers.resize(n);
        counts.resize(n);
        fill(centers,0);
        fill(counts,0);
        
        for(int i=0;i<labels.dim(0);i++) for(int j=0;j<labels.dim(1);j++) {
            int label = labels(i,j);
            centers(label) += i;
            counts(label)++;
        }
        
        counts(0) = 0;
        
        for(int i=0;i<centers.length();i++) {
            if(counts(i)>0) centers(i) /= counts(i);
            else centers(i) = 999999;
        }

        intarray permutation;
        quicksort(permutation,centers);
        intarray rpermutation(permutation.length());
        for(int i=0;i<permutation.length();i++) rpermutation(permutation(i)) = i;
        
        for(int i=0;i<labels.dim(0);i++) for(int j=0;j<labels.dim(1);j++) {
            int label = labels(i,j);
            if(counts(label)==0)
                labels(i,j) = 0;
            else
                labels(i,j) = rpermutation(label)+1;
        }
    }

    static void check_approximately_sorted(intarray &labels) {
        for(int i=0;i<labels.length1d();i++)
            if(labels.at1d(i)>100000)
                throw "labels out of range";
        narray<rectangle> rboxes;
        bounding_boxes(rboxes,labels);
        for(int i=1;i<rboxes.length();i++)
            if(rboxes[i].x1<rboxes[i-1].x0)
                throw "boxes aren't approximately sorted";
    }

    struct StandardGrouper : IGrouper {
        int range;
        intarray labels;
        narray<rectangle> boxes;
        objlist<intarray> segments;
        StandardGrouper() {
        }
        void setSegmentation(intarray &segmentation) {
            copy(labels,segmentation);
            make_line_segmentation_black(labels);
            check_approximately_sorted(labels);
            boxes.dealloc();
            segments.dealloc();
            computeGroups();
        }
        void computeGroups() {
            narray<rectangle> rboxes;
            bounding_boxes(rboxes,labels);
            int n = rboxes.length();
            for(int i=1;i<n;i++) {
                for(int range=1;range<maxrange;range++) {
                    if(i+range>n) continue;
                    rectangle box = rboxes[i];
                    intarray seg;
                    bool bad = 0;
                    for(int j=i;j<i+range;j++) {
                        if(j>i && rboxes[j].x0-rboxes[i].x1>maxdist) {
                            bad = 1;
                            break;
                        }
                        box.include(rboxes[j]);
                        seg.push(j);
                    }
                    if(bad) continue;
                    boxes.push(box);
                    move(segments.push(),seg);
                }
            }
        }
        int length() {
            return boxes.length();
        }
        rectangle boundingBox(int index) {
            return boxes[index];
        }
        void getMask(rectangle &r,bytearray &mask,int index,int grow) {
            r = boxes[index].grow(grow);
            r.intersect(rectangle(0,0,labels.dim(0),labels.dim(1)));
            int x = r.x0, y = r.y0, w = r.width(), h = r.height();
            intarray &segs = segments[index];
            mask.resize(w,h);
            fill(mask,0);
            for(int i=0;i<w;i++) for(int j=0;j<h;j++) {
                int label = labels(x+i,y+j);
                if(first_index_of(segs,label)>=0) {
                    mask(i,j) = 255;
                }
            }
            if(grow>0) dilate_circle(mask,grow);
        }
        template <class T>
        void extractMasked(narray<T> &out,bytearray &mask,narray<T> &source,int index,int grow=0) {
            ASSERT(samedims(labels,source));
            rectangle r;
            getMask(r,mask,index,grow);
            int x = r.x0, y = r.y0, w = r.width(), h = r.height();
            out.resize(w,h);
            fill(out,0);
            for(int i=0;i<w;i++) for(int j=0;j<h;j++) {
                if(mask(i,j))
                    out(i,j) = source(i+x,j+y);
            }
        }
        template <class T>
        void extractWithBackground(narray<T> &out,narray<T> &source,T dflt,int index,int grow=0) {
            ASSERT(samedims(labels,source));
            bytearray mask;
            rectangle r;
            getMask(r,mask,index,grow);
            int x = r.x0, y = r.y0, w = r.width(), h = r.height();
            out.resize(w,h);
            fill(out,dflt);
            for(int i=0;i<w;i++) for(int j=0;j<h;j++) {
                if(mask(i,j))
                    out(i,j) = source(i+x,j+y);
            }
        }
        void extract(bytearray &out,bytearray &mask,bytearray &source,int index,int grow=0) {
            extractMasked(out,mask,source,index,grow);
        }
        void extract(floatarray &out,bytearray &mask,floatarray &source,int index,int grow=0) {
            extractMasked(out,mask,source,index,grow);
        }
        void extract(bytearray &out,bytearray &source,byte dflt,int index,int grow=0) {
            extractWithBackground(out,source,dflt,index,grow);
        }
        void extract(floatarray &out,floatarray &source,float dflt,int index,int grow=0) {
            extractWithBackground(out,source,dflt,index,grow);
        }
        void setClass(int index,int cls,float cost) {
            throw "unimplemented";
        }
    };

    IGrouper *make_StandardGrouper() {
        return new StandardGrouper();
    }
}
