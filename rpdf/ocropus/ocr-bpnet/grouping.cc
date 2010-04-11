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
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites:


// TODO: add garbage collection of unreachable components

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "grid.h"
#include "line-info.h"
#include "segmentation.h"
#include "ocr-utils.h"
#include "logger.h"
#include "lattice.h"
#include "ocr-segmentations.h"
#include "beam-search.h"
#include "make-garbage.h"

using namespace imglib;
using namespace ocropus;
using namespace colib;

#define MAXFLOAT 3.402823466e+38F

namespace {
    Logger align_log("align");
    Logger line_ocr_graph_log("line_ocr.graph");
    Logger line_ocr_log("line_ocr.hilevel");
    Logger line_ocr_transitions_log("line_ocr.transitions");

    struct Mean2 {
        float x,y,n,minx;
        Mean2() {
            x = 0;
            y = 0;
            n = 0;
            minx=MAXFLOAT;
        }
        void add(float nx,float ny) {
            if(nx<minx) minx=nx;
            x += nx;
            y += ny;
            n++;
        }
        float min_x() {
            return minx;
        }
        float mean_x() {
            return x/n;
        }
        float mean_y() {
            return y/n;
        }
    };
}

namespace sort {
    float *compare_f;

    void index(intarray &index,floatarray &values) {
        int n = values.length();
        index.resize(n);
        for(int i=0;i<n;i++) index(i) = i;
        compare_f = &values(0);
        quicksort(index,values);
    }
};

//#if 0 /* CODE-OK--tmb */
param_int maxcomp("maxcomp",5,"max number of components to group together");
param_int maxgap("maxgap",8/*1 gives too many spaces*/,"max gap in pixels between bounding boxes grouped together");
param_string baseline("baseline",NULL,"baseline info in the form \"m,b,d,eps\"");
param_string size("size","2,2,100,100","size range for resulting components \"w0,h0,w1,h1\"");
param_string smallsize("smallsize","2,2","min size for subcomponents to be added\"w,h\"");
param_int maxonly("maxonly",0,"returns maximal possible connected component w/o maxgap in between");
param_int mergeabove("mergeabove",0,"only merge components if one is above the other");
//#endif

// FIXME make these algorithmically settable

#if 0
param_int maxcomp("maxcomp",5,"max number of components to group together");
param_int maxgap("maxgap",8,"max gap in pixels between bounding boxes grouped together");
param_string baseline("baseline",NULL,"baseline info in the form \"m,b,d,eps\"");
param_string size("size",NULL,"size range for resulting components \"w0,h0,w1,h1\"");
param_string smallsize("smallsize",NULL,"min size for subcomponents to be added\"w,h\"");
param_int maxonly("maxonly",0,"returns maximal possible connected component w/o maxgap in between");
param_int mergeabove("mergeabove",0,"only merge components if one is above the other");
#endif

param_string debug_group("debug_group",NULL,"write the grid of oversegmented letters");
param_string debug_info("debug_info",NULL,"write grouping information");

/// \brief A Transition is a segment group OCR'd into a sequence of characters.
///
/// Normally, this sequence will just contain one character.
/// But sometimes the classifier might return several characters.
/// In that case, we're not going to worry about which segment belongs to
/// which character because this most likely wouldn't make sense (otherwise
/// it would be better to recognize it as several segment groups).
/// So we'll idmap all segments to all characters.

namespace {
    struct Transition {
        int segid_from;     //< The segment ID that begins this group (incl.).
        int segid_to;       //< The segment ID that ends this group (excl.).
        intarray points;    //< FST node indices of everything but the endpoint.
        nustring characters; //< The character sequence from the classifier.

        /// Index of the endpoint.
        /// If `is_virtual', the real index will be searched in the "vtable".
        /// This is necessary because the a real (FST node) index can be
        /// determined only after all the previous segments are mapped to their
        /// FST node indices.
        int endpoint;

        /// Costs for every character.
        floatarray costs;

        bool start_is_virtual;
        bool endpoint_is_virtual;

        int id;

        Transition() :
            segid_from(-1),
            segid_to(-1),
            endpoint(-1),
            start_is_virtual(false),
            endpoint_is_virtual(true),
            id(-1)
        {
        }

        void resize(int n) {
            characters.resize(n);
            points.resize(n);
            costs.resize(n);
        }

        void check() {
            ASSERT(segid_from >= 0);
            ASSERT(segid_to   >= 0);
            ASSERT(endpoint   >= 0);
            ASSERT(points.length() == characters.length());
            ASSERT(costs.length() == characters.length());
        }

        /// Add the chain of transitions to the language model.
        /// The start is searched in `vtable' if `start_is_virtual'.
        /// The end is searched in `vtable' if `endpoint_is_virtual'.
        /// Otherwise, they're assumed to be node indices.
        /// (This virtual stuff is necessary because
        ///  we just can't know some node indices
        ///  when the Transition is created).
        /// All segments will be bound to all characters in the idmap.
        /// \param vtable - the table of indices to search for the endpoint
        void add_to(IGenericFst &fst, intarray &vtable, idmap &im) {
            check();
            int prev = start_is_virtual ? vtable[points[0]] : points[0];
            for(int i = 0; i < characters.length(); i++) {
                for(int seg = segid_from; seg < segid_to; seg++)
                    im.associate(id, seg + 1);
                int t;
                if(i == characters.length() - 1)
                    t = (endpoint_is_virtual ? vtable[endpoint] : endpoint);
                else
                    t = points[i+1];
                fst.addTransition(prev,t,characters[i].ord(),costs[i],id);
                line_ocr_transitions_log.format("transition `%c' id %d from %d to %d costs %f",
                    characters[i].ord(), id, prev, t, costs[i]);
                prev = t;
            }
        }
    };
}

static void add_all_transitions(IGenericFst &fst,
                                idmap &im,
                                intarray &vtable,
                                objlist<Transition> &transitions) {
    for(int i = 0; i < transitions.length(); i++)
        transitions[i].add_to(fst, vtable, im);
}


static void renumber_components_by_x_coordinate(intarray &image, int nlabels) {
    narray<Mean2> means(nlabels);
    for(int i=0;i<image.dim(0);i++) for(int j=0;j<image.dim(1);j++) {
            int pixel = image(i,j);
            if(pixel==0) continue;
            means(pixel).add(i,j);
        }
    floatarray xs(nlabels);
    xs(0) = -1;
    for(int i=1;i<nlabels;i++) {
        xs(i) = means(i).mean_x(); //less sensitive to tails
        if(maxonly==1) xs(i) = means(i).min_x();
    }
    intarray sorted;
    sort::index(sorted,xs);
    for(int i=0;i<image.dim(0);i++) for(int j=0;j<image.dim(1);j++) {
        int pixel = image(i,j);
        if(pixel==0) continue;
        image(i,j) = sorted(pixel);
    }
}


static void add_all_variants(objlist<Transition> &transitions,
                             int &fst_nodes_allocated,
                             ICharacterClassifier &classification,
                             int fst_node_from,
                             int from,
                             int to,
                             int id) {
    for(int k = 0; k < classification.length(); k++) {
        nustring variant;
        classification.cls(variant, k);
        ASSERT(variant.length());
        float cost_per_char = classification.cost(k) / variant.length();

        Transition &t = transitions.push();
        t.segid_from = from;
        t.segid_to = to;
        t.id = id;
        t.resize(variant.length());
        // FIXME: normalization doesn't work. I would suggest:
        // double sum_scores = sum(scores), but I'm not sure if this is correct
        // in case of multiple character output. In this case we have probably
        // to calculate this:
        // double sum_scores = 0;
        // for(int c = 0; c < classes.dim(0); c++)
        //     sum_scores += scores(c,m);
        // inside the loop where we calculate t.costs[m] = -log(scores(k,m));
        // or better calculating it ones at the beginnig of the function and
        // store it into floatarray sum_score and then use it in the loop. But
        // in general I don't think that normalization is the right thing to
        // do. One other problem with normalization could be, that we ignore
        // garbage.

        //double sum_scores = 0;
        //for(int m = 0; m < classes.dim(1); m++)
        //    sum_scores += scores(k,m);
        //ASSERT(sum_scores > 0); 
        for(int m = 0; m < variant.length(); m++) {
            t.characters[m] = variant[m];
            //t.costs[m] = -log(scores(k,m) / sum_scores);
            t.costs[m] = cost_per_char;
        }

        t.points[0] = fst_node_from;
        // allocate intermediate nodes
        for(int m = 1; m < variant.length(); m++)
            t.points[m] = fst_nodes_allocated++;
        t.endpoint = to;
        t.endpoint_is_virtual = true; // we can't know the node of cut `to' yet
        t.check();
    }
}


static int extract_merged_component(bytearray &sub, intarray &image,
                                    rectangle r, int i, int j,
                                    float slope, int maxShift) {
    sub.resize(r.width(), r.height() + maxShift + 1);
    // 'erase' sub => paint all white
    fill(sub, 255);
    int numpixels=0;
    int shift = 0;
    for(int x=r.x0;x<r.x1;x++) for(int y=r.y0;y<r.y1;y++) {
        int pixel = image(x,y);
        // only take pixels of the currently merged components
        pixel = (pixel>=i&&pixel<=j);
        int pX, pY;
        pX = x-r.x0;
        pY = y-r.y0;
        // shift the sub image according to slope
        // (use x center of bbox for correction)
        if(x==r.x0) {
            shift = 0;
            if(slope > 0.f) shift += maxShift;
            //shift -= (int) (slope * ((float) (r.x0+r.x1))/2.f);
            shift -= (int) (slope * (float)x);
        }
        // draw baseline (for debugging)
        //if(pY + shift == basepoint) sub(pX, pY + shift) = 200;
        if(pixel) {
            // paint data in black
            sub(pX, pY + shift) = 0;
            numpixels++;
        }
    }
    return numpixels;
}


/*static void check_classes_and_scores(nustring &classes, floatarray &scores) {
    ASSERT(classes.rank() == 2); // multi-character output
    ASSERT(samedims(classes, scores));
    for(int i = 0; i < classes.length1d(); i++) {
        if(classes.at1d(i).ord())
            CHECK_CONDITION(scores.at1d(i) > -1e-6);
    }
}*/


// FIXME this function is way too long, please refactor --tmb

static void lineOCR(IGenericFst &fst, idmap &im, intarray &orig_image, ICharacterClassifier &classifier, bool use_line_info = true) {
    intarray image;
    check_line_segmentation(orig_image);
    copy(image, orig_image);
    make_line_segmentation_black(image);

    Grid debug_grid;
    stdio info;
    if(debug_group)
        debug_grid.create();
    if(debug_info)
        info = stdio(debug_info, "w");


#if 0
    int maxcomp = igetenv("maxcomp",4);
    int maxgap = igetenv("maxgap",8);
    int maxonly = igetenv("maxonly",0);
    int mergeabove = igetenv("mergeabove",0);
#endif

    float bm,bb,bd,be;
    if(baseline) {
        if(sscanf(baseline,"%f,%f,%f,%f",&bm,&bb,&bd,&be)!=4)
            throw "baseline info format error";
        bd = bb-bd;
    }
    int w0,h0,w1,h1;
    if(size) {
        if(sscanf(size,"%d,%d,%d,%d",&w0,&h0,&w1,&h1)!=4)
            throw "size info format error";
    }

    int sw, sh;
    if(smallsize) {
        if(sscanf(smallsize,"%d,%d",&sw,&sh)!=2)
            throw "smallsize info format error";
    }

    int nlabels = renumber_labels(image,1);

    renumber_components_by_x_coordinate(image, nlabels);

    narray<rectangle> bboxes;
    bounding_boxes(bboxes, image);

    float intercept;
    float slope;
    float xheight;
    float descender_sink;
    float ascender_rise;

    if(!get_extended_line_info(intercept,slope,xheight,descender_sink,
                              ascender_rise,image)) {
        intercept = 0;
        slope = 0;
        xheight = 0;
        descender_sink = 0;
        ascender_rise = 0;
    }
    xheight = estimate_xheight(orig_image, slope);

    int basepoint = (int) intercept;

    int lastInto = -1;
    int lastRightEdge = 100000;
    narray<bool> spaces_added;
    spaces_added.resize(nlabels + 1);
    fill(spaces_added, false);
    int maxShift = abs((int) (slope * (float) image.dim(0)));
    if (slope > 0.f) basepoint += maxShift;
    if (basepoint == 0) basepoint = 1;

    if (debug_group) {
        bytearray lineInfoImage(1, image.dim(1) + maxShift + 1);
        // initialize "all white"
        fill(lineInfoImage, 255);
        lineInfoImage(0, basepoint) = 0;

        // -- mark descender --
        int descender = basepoint - (int) descender_sink;
        // descender must not be below bounding box!
        if (descender < 0 || descender == basepoint) descender = 0;
        lineInfoImage(0, descender) = 0;

        // -- mark x-height --
        // xHeight and basepoint must not be at the same pixel!
        if (xheight == 0) xheight = 1;
        // limit x-height to not exceed bounding box
        if (basepoint + xheight >= lineInfoImage.dim(1)) {
            xheight = lineInfoImage.dim(1) - 2 - basepoint;
        }
        lineInfoImage(0, int(basepoint + xheight)) = 0;
        // -- mark ascender (for now top) --
        lineInfoImage(0, lineInfoImage.dim(1)-1) = 0;
        debug_grid.add(lineInfoImage);
    }

    // ________________________________________________________________________
    // extract ranges of connected components
    // Note: the older skript "classify_simple.sh" relied on a slightly different version of the following code
    //       if you intend to use a classifier based on connected components, please check out revision 180

    // We are going to translate the segment ids into FST node ids.
    // One segment interval (a continuous sequence of segments) may produce
    // more then one FST nodes, for example, for ligatures.
    intarray fst_node_ids(nlabels);
    fill(fst_node_ids, -1);
    int fst_nodes_allocated = 0;
    objlist<Transition> transitions;
    narray<bool> referred(nlabels);
    fill(referred, false);
    intarray fst_afterspace_ids(nlabels);
    fill(fst_afterspace_ids, -1);

    int offset=1;
    // start with id 1
    int id = 1;
    for(int i=1;i<nlabels;i+=offset) {
        for(int j=i;j<min(nlabels,i+maxcomp);j++) {
            if(maxonly==1) {
                j=min(nlabels,i+maxcomp)-1;
                offset=j-i+1;
            }
            rectangle r;
            bool skip = false;
            for(int k=i;k<=j;k++) {
                //if(k>i && (bboxes(k).x0-bboxes(k-1).x1) > maxgap) 
                if(k>i && (((bboxes(k).x0-r.x1) > maxgap) ||  //since bboxes(k-1).x1 might be smaller then r.x1
                           (mergeabove && (r.x1>=r.x0) && (bboxes(k).y0<r.y1 && bboxes(k).y1>r.y0)))) {
                    // only merge if one cc is above other
                    // not sure if(r.x1>=r.x0) is necessary here, because we already know that k>i ...
                    if(maxonly==1) offset=k-i;
                    skip = true;
                    break;
                }
                if(smallsize) { // don't add small connected "sub"-components, e.g. single pixel...
                    if(bboxes(k).width()<sw||bboxes(k).height()<sh) continue;
                }
                r.include(bboxes(k));
            }


            if(skip && maxonly==0) break;

            // the merged component must be on the baseline
            if(baseline) {
                float x = (r.x0+r.x1)/2;
                float y = r.y0;
                float py = bm*x+bb;
                float pyd = bm*x+bd;
                float error = min(fabs(py-y),fabs(pyd-y));
                if(error>be) continue;
            }

            // the merged component must be within size range
            if(size) {
                if(r.width()<w0||r.width()>w1||r.height()<h0||r.height()>h1) continue;
            }

            int bottomBak = 0, topBak = 0;
            bottomBak = r.y0;
            topBak = r.y1;
            r.y0 = 0;
            r.y1 = image.dim(1);


            /////////////////////////////////////////////////////
            // extract pixels belonging to the merged component
            bytearray sub;
            extract_merged_component(sub, image, r, i, j, slope, maxShift);
            //int npixels = extract_merged_component(sub, image, r, i, j, slope, maxShift);
            r.y0 = bottomBak;
            r.y1 = topBak;
            // FIXME: problems with gaps in the hypothesis graph. That means no
            // optimal path can be found.
            // only add merged components that have a minimum number of pixels
            //if(npixels<4) continue;

            // FIXME: problems with gaps in the hypothesis graph. That means no
            // optimal path can be found.
            // only add merged components that have a minimum "blackness"
            //float blackness = ((float)npixels)/(float)(r.width()*r.height());
            //if(blackness<0.1) continue;

            // scaled is not used...
            // bytearray scaled(16,16);
            // rescale(scaled,sub);
            int from = i - 1;
            int into = j+offset-1+((maxonly==1&&i==nlabels-1)?1:0);
            if (debug_info)
                fprintf(info,"%d:%d %d,%d,%d,%d\n",from + 1,into,r.x0,r.y0,r.x1,r.y1);

            // Allocate a FST node for the starting segment if not done yet
            if(fst_node_ids[from] == -1) {
                fst_node_ids[from] = fst_nodes_allocated++;
            }

            int fst_node_from = fst_node_ids[from];
            if(fst_afterspace_ids[from] != -1)
                fst_node_from = fst_afterspace_ids[from];
            else if(from == lastInto || r.x0 - lastRightEdge > xheight / 2) {
                // add two arcs in parallel one allowing for a space (t1), the
                // other one not (t2); an id of 0 means that it's an EPSILON

                // add whitespace before the `from' segment (EPSILON:SPACE/0.0)
                Transition &t1 = transitions.push();
                t1.segid_from = from;
                t1.segid_to = from;
                t1.id = 0;
                t1.resize(1);
                t1.characters[0] = nuchar(' ');
                // FIXME: add heuristic function that adjusts the weights for
                // adding a space
                //float space_width = float(r.x0-lastRightEdge);
                //float a = 1.0;
                //float b = xheight/2;
                //float space_prob = 1/(1+exp(-(a*space_width-b)));
                //float space_weight = -log(space_prob);
                //t1.costs[0] = space_weight;
                t1.costs[0] = 0;
                t1.points(0) = lastInto;
                t1.start_is_virtual = true;

                // add no whitespace before the `from' segment (EPSILON:EPSILON/0.0)
                Transition &t2 = transitions.push();
                t2.segid_from = from;
                t2.segid_to = from;
                t2.id = 0;
                t2.resize(1);
                t2.characters[0] = nuchar(0);
                // FIXME: add heuristic function that adjusts the weights for
                // not adding a space
                //float no_space_weight = -log(1-space_prob);
                //t2.costs[0] = no_space_weight;
                t2.costs[0] = 0;
                t2.points(0) = lastInto;
                t2.start_is_virtual = true;

                //printf("space_width: %g xheight/2: %f space_weight: %f "
                //       "no_space_weight: %g\n",space_width,xheight/2,
                //       space_weight,no_space_weight);

                line_ocr_graph_log.format("adding (possible) space from %d to %d",
                    fst_node_from, fst_nodes_allocated);
                fst_node_from = fst_nodes_allocated++;
                fst_afterspace_ids[from] = fst_node_from;
                t1.endpoint = fst_node_from;
                t1.endpoint_is_virtual = false;
                t1.check();
                t2.endpoint = fst_node_from;
                t2.endpoint_is_virtual = false;
                t2.check();
            }

            lastInto = into;
            lastRightEdge = r.x1;

            // classify and add

            if(use_line_info) {
                float baseline = intercept + r.x0 * slope;
                float ascender = baseline + xheight + descender_sink;
                classifier.set(sub, (int) (baseline +  .5),
                                    (int) (xheight +   .5),
                                    (int) (baseline - descender_sink + .5),
                                    (int) (ascender +  .5));
            } else {
                classifier.set(sub);
            }

            //check_classes_and_scores(classes, scores);
            if(debug_group)
                debug_grid.add(sub);
            line_ocr_graph_log.format("adding segment from %d to %d", from, into);
            line_ocr_graph_log("picture", sub);
            line_ocr_graph_log.format("fst_nodes_allocated (before) is %d",
                fst_nodes_allocated);
            add_all_variants(transitions, fst_nodes_allocated,
                             classifier,
                             fst_node_from,
                             from, into, id++);
            line_ocr_graph_log.format("fst_nodes_allocated (after) is %d",
                fst_nodes_allocated);
            if(classifier.length())
                referred[into] = true;
        }
    }

    for(int i = 0; i < nlabels; i++) {
        if(referred[i] && fst_node_ids[i] == -1)
            fst_node_ids[i] = fst_nodes_allocated++;
    }

    /*
      for(int i = 0; i <= nlabels; i++) {
      if(!spaces_added[i]) {
      fst.add_transition(2 * i, 2 * i + 1, -1, 0, id++);
      }
      }*/
    
    //fst.start_chunk(fst_nodes_allocated);

    if(!fst_nodes_allocated)
        fst_nodes_allocated = 1;
    for(int i=0;i<fst_nodes_allocated;i++) {
        fst.newState();
    }
    add_all_transitions(fst, im, fst_node_ids, transitions);
    fst.setStart(0);
    fst.setAccept(fst_nodes_allocated-1,0.0);        
    if(debug_group)
        debug_grid.save(debug_group);
}


namespace ocropus {

#if 0
    struct Grouper : IGrouper {
        int fst_nodes_allocated;
        

        virtual void setSegmentation(colib::intarray &segmentation) = 0;
        virtual int length() = 0;
        virtual void getMask(colib::rectangle &r,colib::bytearray &mask,int index,int margin) = 0;
        virtual colib::rectangle boundingBox(int index) = 0;
        virtual void extract(colib::bytearray &out,colib::bytearray &mask,colib::bytearray &source,int index,int grow=0) = 0;
        virtual void extract(colib::floatarray &out,colib::bytearray &mask,colib::floatarray &source,int index,int grow=0) = 0;
        virtual void extract(colib::bytearray &out,colib::bytearray &source,colib::byte dflt,int index,int grow=0) = 0;
        virtual void extract(colib::floatarray &out,colib::floatarray &source,float dflt,int index,int grow=0) = 0;
        virtual void setClass(int index,int cls,float cost) = 0;

        virtual void outputCharLattice(colib::IGenericFst &lattice) {
            for(int i=0;i<fst_nodes_allocated;i++) {
                lattice.newState();
            }
            add_all_transitions(lattice, im, fst_node_ids, transitions);
            lattice.setStart(0);
            lattice.setAccept(fst_nodes_allocated-1,0.0);        
        }
    };
#endif

    struct NewGroupingLineOCR : IRecognizeLine {
        autodel<ICharacterClassifier> classifier;
        autodel<ISegmentLine> segmenter;
        bool use_line_info;

        NewGroupingLineOCR(ICharacterClassifier *c,
                           ISegmentLine *s,
                           bool use_line_info) :
             classifier(c), segmenter(s), use_line_info(use_line_info) {
        }

        const char *description() {
            return "NewGroupingLineOCR";
        }

        void init(const char **) {
        }

        void recognizeLine(IGenericFst &result,/*idmap &components,
                           intarray &segmentation,*/bytearray &image) {
            line_ocr_log("input", image);
            bytearray binarized;
            binarize_simple(binarized, image);
            line_ocr_log("binarized", binarized);
            intarray segmentation;
            segmenter->charseg(segmentation, binarized);
            line_ocr_log.recolor("overseg", segmentation);
            idmap components;
            lineOCR(result,components,segmentation,*classifier,use_line_info);
            line_ocr_log("result", result);
        }

        virtual void addTrainingLine(intarray &trueseg, bytearray &image, nustring &chars) {
            rectarray bboxes;
            bounding_boxes(bboxes, trueseg);
            for(int i = 1; i < bboxes.length(); i++) {
                intarray segment;
                rectangle &b = bboxes[i];
                extract_subimage(segment,trueseg,b.x0,b.y0,b.x1,b.y1);
                bytearray subimage;
                extract_segment(subimage,segment,i);
                nustring char_text;
                char_text.resize(1);
                char_text[0] = chars[i - 1];
                classifier->addTrainingChar(subimage, char_text);
            }

            rectarray garbage_bboxes;
            narray<bytearray> garbage;
            make_garbage(garbage_bboxes, garbage, trueseg);
            for(int i = 0; i < garbage.length(); i++) {
                nustring char_text;
                char_text.resize(1);
                char_text[0] = nuchar(0xAC);
                classifier->addTrainingChar(garbage[i], char_text);
            }
        }

	virtual void startTraining(const char *type="adaptation") {
            classifier->startTraining(type);
        }
        virtual void addTrainingLine(bytearray &image,nustring &transcription) {
            autodel<IGenericFst> fst(make_StandardFst());
            int k = transcription.length();
            floatarray costs(k);
            intarray ids(k);
            for(int i = 0; i < k; i++) {
                costs[i] = 0;
                ids[i] = i + 1;
            }
            fst->setString(transcription, costs, ids);
            costs.clear();
            nustring chars;
            intarray trueseg;
            align(chars, trueseg, costs, image, *fst);
            addTrainingLine(trueseg, image, chars);
        }
	virtual void finishTraining() {
            classifier->finishTraining();
        }
        virtual void align(nustring &chars,intarray &result,floatarray &result_costs, bytearray &image,IGenericFst &transcription) {
            align_log("alignment: ", image);
            if(align_log.enabled) {
                nustring s;
                transcription.bestpath(s);
                align_log("ground truth", s);
            }

            bytearray binarized;
            binarize_simple(binarized, image);
            align_log("binarized", binarized);
            intarray segmentation;
            segmenter->charseg(segmentation, binarized);
            align_log.recolor("overseg", segmentation);
            idmap components;
            autodel<IGenericFst> fst(make_StandardFst());
            lineOCR(*fst,components,segmentation,*classifier);
            // align
            autodel<CompositionFst> composition(
                make_CompositionFst(fst.move(), &transcription));
            intarray ids;
            intarray vertices;
            intarray outputs;
            floatarray costs;
            beam_search(ids, vertices, outputs, costs, *composition);
            composition->move2(); // we don't own the transcript
            // remove zeros from ids
            intarray ids_cleaned;
            for(int i = 0; i < ids.length(); i++) {
                if(ids[i]) {
                    ids_cleaned.push(ids[i]);
                    align_log("id", ids[i]);
                }
            }
            // build the output string
            for(int i = 0; i < outputs.length(); i++) {
                if(outputs[i]) {
                    chars.push(nuchar(outputs[i]));
                    result_costs.push(costs[i]);
                }
            }
            align_log("chars", chars);
            // recolor
            ocr_result_to_charseg(result, components,
                                  ids_cleaned, segmentation);

            align_log.recolor("result", result);
        }

    };

    IRecognizeLine *make_NewGroupingLineOCR(ICharacterClassifier *classifier, ISegmentLine *segmenter, bool use_line_info) {
        return new NewGroupingLineOCR(classifier, segmenter, use_line_info);
    }
}

