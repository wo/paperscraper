// -*- C++ -*-

// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// Copyright 1995-2005 by Thomas M. Breuel
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
// Web Sites: 


// FIXME this should really work "word"-wise, centered on each word,
// otherwise it does the wrong thing for non-deskewed lines

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <ctype.h>
#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "segmentation.h"
#include "queue.h"
#include "ocr-utils.h"
#include "ocr-segmentations.h"
#include "logger.h"

using namespace ocropus;
using namespace imgio;
using namespace imglib;
using namespace colib;

namespace {
    Logger log_main("lineseg.seg-cuts");
}

static void local_min(floatarray &result,floatarray &data,int r) {
    int n = data.length();
    result.resize(n);
    for(int i=0;i<n;i++) {
        float lmin = data(i);
        for(int j=-r;j<=r;j++) {
            int k = i+j;
            if(unsigned(k)>=unsigned(n)) continue;
            if(data(k)>=lmin) continue;
            lmin = data(k);
        }
        result(i) = lmin;
    }
}

static void local_minima(intarray &result,floatarray &data,int r,float threshold) {
    int n = data.length();
    result.clear();
    floatarray lmin;
    local_min(lmin,data,r);
    for(int i=1;i<n-1;i++) {
        if(data(i)<=threshold && data(i)<=lmin(i) &&
           data(i)<=data(i-1) && data(i)<data(i+1)) {
            result.push(i);
        }
    }
}

////////////////////////////////////////////////////////////////
//
// could be moved into a header file

struct CurvedCutSegmenter {
    int down_cost;
    int outside_diagonal_cost;
    int inside_diagonal_cost;
    int boundary_diagonal_cost;
    int inside_weight;
    int boundary_weight;
    int outside_weight;
    int min_range;
    float min_thresh;
    //virtual void params_for_chars() = 0;
    virtual void params_for_lines() = 0;
    virtual void find_allcuts() = 0;
    virtual void find_bestcuts() = 0;
    // virtual void relabel_image(bytearray &image) = 0;
    // virtual void relabel_image(intarray &image) = 0;
    virtual void set_image(bytearray &image) = 0;
    virtual ~CurvedCutSegmenter() {}
};


//
////////////////////////////////////////////////////////////////

struct CurvedCutSegmenterImpl : CurvedCutSegmenter {
    // input
    intarray wimage;
    int where;

    // output
    intarray costs;
    intarray sources;
    int direction;
    int limit;

    intarray bestcuts;

    strbuf debug;
    intarray dimage;
    
    narray< narray <point> > cuts;
    floatarray cutcosts;

    CurvedCutSegmenterImpl() {
        //params_for_chars();
        params_for_lines();
        //params_from_hwrec_c();
    }

    void params_for_lines() {
        down_cost = 0;
        outside_diagonal_cost = 4;
        inside_diagonal_cost = 4;
        boundary_diagonal_cost = 0;
        outside_weight = 0;     
        boundary_weight = -1;   
        inside_weight = 4;      
        min_range = 3;
        //min_thresh = -2.0;
        min_thresh = 10.0;
    }

#if 0
    void params_for_chars() {
        down_cost = 0;
        outside_diagonal_cost = 1;
        inside_diagonal_cost = 4;
        boundary_diagonal_cost = 0;
        outside_weight = 0;
        boundary_weight = -1;
        inside_weight = 4;
        min_range = 3;
        min_thresh = 100.0;
    }

    void params_from_hwrec_c() { 
        down_cost = 0;
        outside_diagonal_cost = 1;  
        inside_diagonal_cost = 1;  
        boundary_diagonal_cost = 1;
        outside_weight = 0;     
        boundary_weight = -5;   
        inside_weight = 2;      
        min_range = 3;
        min_thresh = -5.0;
    }
#endif

    // this function calculates the actual costs!
    void step(int x0,int x1,int y) {
        int w = wimage.dim(0),h = wimage.dim(1);
        Queue<point> queue(w*h);
        for(int i=x0;i<x1;i++) queue.enqueue(point(i,y));
        int low = 1;
        int high = wimage.dim(0)-1;
        
        while(!queue.empty()) {
            point p = queue.dequeue();
            int i = p.x, j = p.y;
            int cost = costs(i,j);
            int ncost = cost+wimage(i,j)+down_cost;
            if(costs(i,j+direction)>ncost) {
                costs(i,j+direction) = ncost;
                sources(i,j+direction) = i;
                if(j+direction!=limit) queue.enqueue(point(i,j+direction));
            }
            if(i>low) {
                if(wimage(i,j)==0)
		    ncost = cost+wimage(i,j)+outside_diagonal_cost;
                else if(wimage(i,j)>0)
		    ncost = cost+wimage(i,j)+inside_diagonal_cost;
                else if(wimage(i,j)<0)
		    ncost = cost+wimage(i,j)+boundary_diagonal_cost;
                if(costs(i-1,j+direction)>ncost) {
                    costs(i-1,j+direction) = ncost;
                    sources(i-1,j+direction) = i;
                    if(j+direction!=limit) queue.enqueue(point(i-1,j+direction));
                }
            }
            if(i<high) {
                if(wimage(i,j)==0)
		    ncost = cost+wimage(i,j)+outside_diagonal_cost;
                else if(wimage(i,j)>0)
		    ncost = cost+wimage(i,j)+inside_diagonal_cost;
                else if(wimage(i,j)<0)
		    ncost = cost+wimage(i,j)+boundary_diagonal_cost;
                if(costs(i+1,j+direction)>ncost) {
                    costs(i+1,j+direction) = ncost;
                    sources(i+1,j+direction) = i;
                    if(j+direction!=limit) queue.enqueue(point(i+1,j+direction));
                }
            }
        }
    }

    void find_allcuts() {
        int w = wimage.dim(0), h = wimage.dim(1);
        // initialize dimensions of cuts, costs etc
        cuts.resize(w);
        cutcosts.resize(w);
        costs.resize(w,h);
        sources.resize(w,h);

        fill(costs, 1000000000);
        for(int i=0;i<w;i++) costs(i,0) = 0;
        fill(sources, -1);
        limit = where;
        direction = 1;
        step(0,w,0);

        for(int x=0;x<w;x++) {
            cutcosts(x) = costs(x,where);
            cuts(x).clear();
            // bottom should probably be initialized with 2*where instead of
            // h, because where cannot be assumed to be h/2. In the most extreme
            // case, the cut could go through 2 pixels in each row
            narray<point> bottom;
            int i = x, j = where;
            while(j>=0) {
                bottom.push(point(i,j));
                i = sources(i,j);
                j--;
            }
            //cuts(x).resize(h);
            for(i=bottom.length()-1;i>=0;i--) cuts(x).push(bottom(i));
        }

        fill(costs, 1000000000);
        for(int i=0;i<w;i++) costs(i,h-1) = 0;
        fill(sources, -1);
        limit = where;
        direction = -1;
        step(0,w,h-1);

        for(int x=0;x<w;x++) {
            cutcosts(x) += costs(x,where);
            // top should probably be initialized with 2*(h-where) instead of
            // h, because where cannot be assumed to be h/2. In the most extreme
            // case, the cut could go through 2 pixels in each row
            narray<point> top;
            int i = x, j = where;
            while(j<h) {
                if(j>where) top.push(point(i,j));
                i = sources(i,j);
                j++;
            }
            for(i=0;i<top.length();i++) cuts(x).push(top(i));
        }

        // add costs for line "where"
        for(int x=0;x<w;x++) {
            cutcosts(x) += wimage(x,where);
        }

    }

    void find_bestcuts() {
	for(int i=0;i<cutcosts.length();i++) ext(dimage,i,int(cutcosts(i)+10)) = 0xff0000;
	for(int i=0;i<cutcosts.length();i++) ext(dimage,i,int(min_thresh+10)) = 0x800000;
        local_minima(bestcuts,cutcosts,min_range,min_thresh);
	for(int i=0;i<bestcuts.length();i++) {
	    narray<point> &cut = cuts(bestcuts(i));
	    for(int j=0;j<cut.length();j++) {
		point p = cut(j);
		ext(dimage,p.x,p.y) = 0x00ff00;
	    }
	}
	if(debug) write_png_rgb(stdio(debug,"w"),dimage);
    }

    void set_image(bytearray &image) {
	copy(dimage,image);
        int w = image.dim(0), h = image.dim(1);
        wimage.resize(w,h);
        fill(wimage, 0);
        float s1 = 0.0, sy = 0.0;
        for(int i=1;i<w;i++) for(int j=0;j<h;j++) {
            if(image(i,j)) { s1++; sy += j; }
            if(!image(i-1,j) && image(i,j)) wimage(i,j) = boundary_weight;
            else if(image(i,j)) wimage(i,j) = inside_weight;
            else wimage(i,j) = outside_weight;
        }
        where = int(sy/s1);
	for(int i=0;i<dimage.dim(0);i++) dimage(i,where) = 0x008000;
    }
};

// CurvedCutSegmenter *makeCurvedCutSegmenter() {
//  return new CurvedCutSegmenterImpl();
// }

class CurvedCutSegmenterToISegmentLineAdapter : public ISegmentLine {
    autoref<CurvedCutSegmenterImpl> segmenter;

    virtual const char *description() {
        return "curved cut segmenter";
    }

    virtual void set(const char *key,const char *value) {
        log_main.format("set parameter %s to sf", key, value);
	if(!strcmp(key,"debug"))
	    segmenter->debug = value;
	else
	    throw "unknown key";
    }

    virtual void set(const char *key,double value) {
        log_main.format("set parameter %s to %f", key, value);
        if(!strcmp(key,"down_cost"))
	    segmenter->down_cost = (int)value;
        else if(!strcmp(key,"outside_diagonal_cost"))
	    segmenter->outside_diagonal_cost = (int)value;
        else if(!strcmp(key,"inside_diagonal_cost"))
	    segmenter->inside_diagonal_cost = (int)value;
        else if(!strcmp(key,"boundary_diagonal_cost"))
	    segmenter->boundary_diagonal_cost = (int)value;
        else if(!strcmp(key,"outside_weight"))
	    segmenter->outside_weight = (int)value;
        else if(!strcmp(key,"boundary_weight"))
	    segmenter->boundary_weight = (int)value;
        else if(!strcmp(key,"inside_weight"))
	    segmenter->inside_weight = (int)value;
        else if(!strcmp(key,"min_range"))
	    segmenter->min_range = (int)value;
        else if(!strcmp(key,"min_thresh"))
	    segmenter->min_thresh = value;
        else
	    throw "unknown key";
    }

    virtual void charseg(intarray &result_segmentation,bytearray &orig_image) {
        log_main("segmenting", orig_image);
        enum {PADDING = 3};
        bytearray image;
        copy(image, orig_image);
        make_page_binary_and_black(image);
        pad_by(image, PADDING, PADDING);
        intarray segmentation;
        // pass image to segmenter
        segmenter->set_image(image);
        // find all cuts in the image
        segmenter->find_allcuts();
        // choose the best of all cuts
        segmenter->find_bestcuts();

        // the method below has two problems:
        //  1) spurious components for thin lines (this could be 
        //     solved by using a more careful cutting strategy than the three pixels
        //     as used below)
        //  2) you can have more that one subimage between two cuts
        //     (this may actually be desired)
        // so let's try a different method: everything between two cuts is one component
        

        segmentation.resize(image.dim(0),image.dim(1));
        for(int i=0;i<image.dim(0);i++) for(int j=0;j<image.dim(1);j++)
            segmentation(i,j) = image(i,j)?0xffffffff:0;

        // first determine connected components
        label_components(segmentation);
        // multiply connected components with 10000
        // so that we can combine it with the cut-information
        for(int i=0;i<image.dim(0);i++) for(int j=0;j<image.dim(1);j++)
            segmentation(i,j) *=10000; 

        // now include the cut-information
        for(int r=0;r<segmenter->bestcuts.length();r++) {
            int c = segmenter->bestcuts(r);
            narray<point> &cut = segmenter->cuts(c);
            for(int y=0;y<image.dim(1);y++) {
                for(int x=cut(y).x;x<image.dim(0);x++) 
                    if(segmentation(x,y)) segmentation(x,y)++;
            }
        }

        renumber_labels(segmentation,1);
        extract_subimage(result_segmentation,segmentation,PADDING,PADDING,
                         segmentation.dim(0)-PADDING,segmentation.dim(1)-PADDING);
        make_line_segmentation_white(result_segmentation);
        set_line_number(result_segmentation, 1);
        log_main("resulting segmentation", result_segmentation);
    }
};

ISegmentLine *ocropus::make_CurvedCutSegmenter() {
    return new CurvedCutSegmenterToISegmentLineAdapter();
}
