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
// File: ocr-utils.cc
// Purpose: miscelaneous routines
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include <stdarg.h>
#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "ocr-utils.h"
#include "sysutil.h"
#include "ocr-segmentations.h"

using namespace imgio;
using namespace imglib;
using namespace colib;

namespace ocropus {

    void invert(bytearray &a) {
        int n = a.length1d();
        for (int i = 0; i < n; i++) {
            a.at1d(i) = 255 - a.at1d(i);
        }
    }

    void crop_masked(bytearray &result,
                     bytearray &source,
                     rectangle crop_rect,
                     bytearray &mask,
                     int def_val,
                     int pad) {
        CHECK_ARG(background_seems_black(mask));

        rectangle box(0, 0, source.dim(0), source.dim(1));
        box.intersect(crop_rect);
        result.resize(box.width() + 2 * pad, box.height() + 2 * pad);
        fill(result, def_val);
        for(int x = 0; x < box.width(); x++) {
            for(int y = 0; y < box.height(); y++) {
               if(mask(x + box.x0, y + box.y0))
                   result(x + pad, y + pad) = source(x + box.x0, y + box.y0);
            }
        }
    }


    int average_on_border(colib::bytearray &a) {
        int sum = 0;
        int right = a.dim(0) - 1;
        int top = a.dim(1) - 1;
        for(int x = 0; x < a.dim(0); x++)
            sum += a(x, 0);
        for(int x = 0; x < a.dim(0); x++)
            sum += a(x, top);
        for(int y = 1; y < top; y++)
            sum += a(0, y);
        for(int y = 1; y < top; y++)
            sum += a(right, y);
        return sum / ((right + top) * 2);
    }

    
    // FIXME use imgmorph stuff
    
    void blit2d(bytearray &dest, const bytearray &src, int shift_x, int shift_y) {
        int w = src.dim(0);
        int h = src.dim(1);
        for (int x=0;x<w;x++) for (int y=0;y<h;y++) {
            dest(x + shift_x, y + shift_y) = src(x,y);
        }
    }

    float median(intarray &a) {
        intarray s;
        copy(s, a);
        quicksort(s);
        int n = s.length();
        if (!n)
            return 0;
        if (n % 2)
            return s[n / 2];
        else
            return float(s[n / 2 - 1] + s[n / 2]) / 2;
    }


    // FIXME comments

    void boxes_height_histogram(floatarray &histogram, narray<rectangle> &bboxes,int max_height) {
        int   i,d;
        histogram.resize(max_height);
        for(i=0;i<max_height;i++) histogram[i] = 0.0;

        int len = bboxes.length();
        for(i=0; i< len; i++){
            d = (int) bboxes[i].y1 - (int) bboxes[i].y0;
            if(d!=0 && d>=0 && d<max_height) histogram[d]++;
        }
    }

    // FIXME comments

    float estimate_boxes_height(narray<rectangle> &bboxes,int h,int min_height,float smooth) {

        int i;
        int best_i;
        float best_v;
        floatarray histogram;

        boxes_height_histogram(histogram, bboxes, h);
        gauss1d(histogram,smooth);

        best_i = -1;
        best_v = -1.0;
        for(i=min_height;i<h;i++) {
            if(histogram[i]<best_v) continue;
            best_i = i;
            best_v = histogram[i];
        }

        if(best_i < min_height)
            best_i = min_height;
        return (float)best_i;
    }


    // FIXME comments

    float estimate_xheight(intarray &orig_seg, float slope) {
        intarray seg;
        copy(seg, orig_seg);
        check_line_segmentation(seg);
        make_line_segmentation_black(seg);
        narray<rectangle> bboxes;
        bounding_boxes(bboxes, seg);

        return estimate_boxes_height(bboxes, seg.dim(1), 10, 4);
    }

    void plot_hist(FILE *stream, floatarray &hist){
        if(!stream){
            fprintf(stderr,"Unable to open histogram image stream.\n");
            exit(0);
        }
        int maxval = 1000;
        int len    = hist.length();
        narray<unsigned char> image(len, maxval);
        fill(image,0xff);
        for(int x=0; x<len; x++){
            int top = min(maxval-1,int(hist[x]));
            for(int y=0; y<top; y++)
                image(x,y) = 0;
        }
        write_png(stream,image);
        fclose(stream);
    }
    
    void paint_box(intarray &image, rectangle r, int color){

        int width  = image.dim(0);
        int height = image.dim(1);
        int left, top, right, bottom;
       
        left   = (r.x0<0)  ? 0   : r.x0;
        top    = (r.y0<0)  ? 0   : r.y0;
        right  = (r.x1>=width) ? width-1 : r.x1;
        bottom = (r.y1>=height) ? height-1 : r.y1;

        if(right <= left || bottom <= top) return;

        for(int x=left; x<right; x++){
            for(int y=top; y<bottom; y++){
                image(x,y) &= color;  
            }
        }
    }

    void paint_box_border(intarray &image, rectangle r, int color){

        int width  = image.dim(0);
        int height = image.dim(1);
        int left, top, right, bottom;
       
        left   = (r.x0<0)  ? 0   : r.x0;
        top    = (r.y0<0)  ? 0   : r.y0;
        right  = (r.x1>=width) ? width-1 : r.x1;
        bottom = (r.y1>=height) ? height-1 : r.y1;
        if(right < left || bottom < top) return;
        int x,y;
        for(x=left; x<=right; x++){ image(x,top)     &=color; }
        for(x=left; x<=right; x++){ image(x,bottom)  &=color; }
        for(y=top; y<=bottom; y++){ image(left,y)    &=color; }
        for(y=top; y<=bottom; y++){ image(right,y)   &=color; }
        
    }

    static void subsample_boxes(narray<rectangle> &boxes, int factor) {
        int len = boxes.length();
        if (factor == 0) return;
        for(int i=0; i<len; i++){
            boxes[i].x0 = boxes[i].x0/factor;
            boxes[i].x1 = boxes[i].x1/factor;
            boxes[i].y0 = boxes[i].y0/factor;
            boxes[i].y1 = boxes[i].y1/factor;
        }
    }


    void draw_rects(colib::intarray &out, colib::bytearray &in,
                    colib::narray<colib::rectangle> &rects,
                    int downsample_factor,  int color){
        int ds = downsample_factor;
        if(ds <= 0)
            ds = 1;
        int width  = in.dim(0);
        int height = in.dim(1);
        int xdim   = width/ds;
        int ydim   = height/ds;
        out.resize(xdim, ydim);
        for(int ix=0; ix<xdim; ix++)
            out(ix,ydim-1)=0x00ffffff;
        for(int x=0,ix=0; x<width-ds; x+=ds, ix++) {
            for(int y=0,iy=0; y<height-ds; y+=ds, iy++){
                out(ix,iy)=in(x,y)*0x00010101;
            }
        }
        narray<rectangle> boxes;
        copy(boxes,rects);
        if(ds > 1)
            subsample_boxes(boxes, ds);

        for(int i=0, len=boxes.length(); i<len; i++)
            paint_box_border(out, boxes[i], color);
        
    }

    void draw_filled_rects(colib::intarray &out, colib::bytearray &in,
                           colib::narray<colib::rectangle> &rects, 
                           int downsample_factor, int color, int border_color){
        int ds = downsample_factor;
        if(ds <= 0)
            ds = 1;
        int width  = in.dim(0);
        int height = in.dim(1);
        int xdim   = width/ds;
        int ydim   = height/ds;
        out.resize(xdim, ydim);
        for(int ix=0; ix<xdim; ix++)
            out(ix,ydim-1)=0x00ffffff;
        for(int x=0,ix=0; x<width-ds; x+=ds, ix++) {
            for(int y=0,iy=0; y<height-ds; y+=ds, iy++){
                out(ix,iy)=in(x,y)*0x00010101;
            }
        }
        narray<rectangle> boxes;
        copy(boxes,rects);
        if(ds > 1)
            subsample_boxes(boxes, ds);

        for(int i=0, len=boxes.length(); i<len; i++){
            paint_box(out, boxes[i], color);
            paint_box_border(out, boxes[i], border_color);
        }
        
    }

    // FIXME comments

    void get_line_info(float &baseline, float &xheight, float &descender, float &ascender, intarray &seg) {
        narray<rectangle> bboxes;
        bounding_boxes(bboxes, seg);

        intarray tops, bottoms;
        makelike(tops,    bboxes);
        makelike(bottoms, bboxes);

        for(int i = 0; i < bboxes.length(); i++) {
            tops[i] = bboxes[i].y1;
            bottoms[i] = bboxes[i].y0;
        }

        baseline = median(bottoms) + 1;
        xheight = median(tops) - baseline;

        descender = baseline - 0.4 * xheight;
        ascender  = baseline + 2 * xheight;
    }

    // FIXME comments

    static const char *version_string = NULL;

    // FIXME comments

    const char *get_version_string() {
        return version_string;
    }

    // FIXME comments
    
    void set_version_string(const char *new_version_string) {
        if (version_string) {
            ASSERT(new_version_string && !strcmp(version_string, new_version_string));
        } else {
            version_string = new_version_string;
        }
    }

    void Timers::report() {
        fprintf(stderr,"time binarizer %g\n",*binarizer);
        fprintf(stderr,"time cleanup %g\n",*cleanup);
        fprintf(stderr,"time page_segmenter %g\n",*page_segmenter);
        fprintf(stderr,"time line_segmenter %g\n",*line_segmenter);
        fprintf(stderr,"time ocr %g\n",*ocr);
        fprintf(stderr,"time langmod %g\n",*langmod);
    }

    void Timers::reset() {
        binarizer.reset();
        cleanup.reset();
        page_segmenter.reset();
        line_segmenter.reset();
        ocr.reset();
        langmod.reset();
    }

    static Timers ocr_timers;

    void report_ocr_timings() {
        ocr_timers.report();
    }

    void reset_ocr_timings() {
        ocr_timers.reset();
    }

    Timers &get_ocr_timings() {
        return ocr_timers;
    }


    void normalize_input_classify(floatarray &feature,doublearray 
                                  &stdev,doublearray &m_x) {
    
        CHECK_ARG(stdev.length()==m_x.length());
        ASSERT(is_nan_free(m_x));
        ASSERT(is_nan_free(stdev));
        int ninput = m_x.length();
        // normalize
        for(int d=0;d<ninput;d++) {
            if(stdev(d)>0) {
                feature(d) = (feature(d)-m_x(d))/stdev(d);
            }
            else {
                feature(d) = feature(d)-m_x(d);     //var=0: all the same;
            }
        }
    }

    void align_segmentation(intarray &segmentation,narray<rectangle> &bboxes) {
        intarray temp;
        make_line_segmentation_black(segmentation);
        renumber_labels(segmentation,1);
        int nsegs = max(segmentation)+1;
        intarray counts;
        counts.resize(nsegs,bboxes.length());
        fill(counts,0);
        for(int i=0;i<segmentation.dim(0);i++) {
            for(int j=0;j<segmentation.dim(1);j++) {
                int cs = segmentation(i,j);
                if(cs==0) continue;
                for(int k=0;k<bboxes.length();k++) {
                    if(bboxes[k].contains(i,j))
                        counts(cs,k)++;
                }
            }
        }
        intarray segmap;
        segmap.resize(counts.dim(0));
        for(int i=0;i<counts.dim(0);i++) {
            int mj = -1;
            int mc = 0;
            for(int j=0;j<counts.dim(1);j++) {
                if(counts(i,j)>mc) {
                    mj = j;
                    mc = counts(i,j);
                }
            }
            segmap(i) = mj;
        }
        for(int i=0;i<segmentation.dim(0);i++) {
            for(int j=0;j<segmentation.dim(1);j++) {
                int cs = segmentation(i,j);
                if(cs) continue;
                segmentation(i,j) = segmap(cs)+1;
            }
        }
    }
    void idmap_of_correspondences(idmap &result,intarray &charseg,intarray &overseg) {
        result.clear();
        for(int i=0;i<charseg.dim(0);i++) for(int j=0;j<charseg.dim(1);j++) {
            if(charseg(i,j)==0 || overseg(i,j)==0) continue;
            result.associate(charseg(i,j),overseg(i,j));
        }
    }
    void idmap_of_bboxes(idmap &result,intarray &overseg,narray<rectangle> &bboxes) {
        intarray charseg;
        copy(charseg,overseg);
        align_segmentation(charseg,bboxes);
        idmap_of_correspondences(result,charseg,overseg);
    }

    namespace {
        void getrow(intarray &a,intarray &m,int i) {
            a.resize(m.dim(1));
            for(int j=0;j<m.dim(1);j++) a(j) = m(i,j);
        }
        void getcol(intarray &a,intarray &m,int j) {
            a.resize(m.dim(0));
            for(int i=0;i<m.dim(0);i++) a(i) = m(i,j);
        }
    }

    void evaluate_segmentation(int &nover,int &nunder,int &nmis,intarray &model_raw,intarray &image_raw,float tolerance) {
        CHECK_ARG(samedims(model_raw,image_raw));

        intarray model,image;
        copy(model,model_raw);
        replace_values(model, 0xFFFFFF, 0);
        int nmodel = renumber_labels(model,1);
        CHECK_ARG(nmodel<100000);

        copy(image,image_raw);
        replace_values(image, 0xFFFFFF, 0);
        int nimage = renumber_labels(image,1);
        CHECK_ARG(nimage<100000);

        intarray table(nmodel,nimage);
        fill(table,0);
        for(int i=0;i<model.length1d();i++)
            table(model.at1d(i),image.at1d(i))++;

//         for(int i=1;i<table.dim(0);i++) {
//             for(int j=1;j<table.dim(1);j++) {
//                 printf(" %3d",table(i,j));
//             }
//             printf("\n");
//         }

        nover = 0;
        nunder = 0;
        nmis = 0;

        for(int i=1;i<table.dim(0);i++) {
            intarray row;
            getrow(row,table,i);
            row(0) = 0;
            double total = sum(row);
            int match = argmax(row);
            // printf("[%3d,] %3d: ",i,match); for(int j=1;j<table.dim(1);j++) printf(" %3d",table(i,j)); printf("\n");
            for(int j=1;j<table.dim(1);j++) {
                if(j==match) continue;
                int count = table(i,j);
                if(count==0) continue;
                if(count / total > tolerance) {
                    nover++;
                } else {
                    nmis++;
                }
            }
        }
        for(int j=1;j<table.dim(1);j++) {
            intarray col;
            getcol(col,table,j);
            col(0) = 0;
            double total = sum(col);
            int match = argmax(col);
            // printf("[,%3d] %3d: ",j,match); for(int i=1;i<table.dim(0);i++) printf(" %3d",table(i,j)); printf("\n");
            for(int i=1;i<table.dim(0);i++) {
                if(i==match) continue;
                int count = table(i,j);
                if(count==0) continue;
                if(count / total > tolerance) {
                    nunder++;
                } else {
                    nmis++;
                }
            }
        }
    }
    void ocr_result_to_charseg(intarray &cseg,idmap &map,intarray &ids,intarray &segmentation,bool map_all) {
        make_line_segmentation_black(segmentation);
        makelike(cseg,segmentation);
        fill(cseg,0);
        intarray cseg_to_char;
        cseg_to_char.resize(max(segmentation)+1);
        fill(cseg_to_char,-1);
        for(int i=0;i<ids.length();i++) {
            // We MUST make gaps for spaces, otherwise the correspondence
            // between characters and segments is not well-defined anymore.
            
            // skip spaces
            if(ids[i] == 0)
                continue;
            intarray l;
            map.segments_of_id(l,ids[i]);
            // there should be at least one segment for each id
            if(map_all && l.length()<1)
                throw "not every segment has a corresponding id";

            for(int j=0;j<l.length();j++) {
                int cs = l[j];
                // This check needs to be discussed since other parts of ocropus
                // don't care about this condition. Also, the fact that segments
                // MAY be shared between ids led to the idmap structure,
                // otherwise we could live happily with objlist<intarray>
                // or something.
                #if 0
                // segments shouldn't be shared between characters
                if(!(cseg_to_char(cs)==-1 || cseg_to_char(cs)==chars_allocated))
                    throw "segments are shared between multiple ids";
                #endif
                cseg_to_char(cs) = i + 1;
            }
        }

        for(int i=0;i<cseg.length1d();i++) {
            int seg = segmentation.at1d(i);
            if(!seg) continue;
            int c = cseg_to_char(seg);
            if(c == -1) continue;
            if(map_all && c<1)
                throw "some pixels in the segmentation are not mapped to a character";
            cseg.at1d(i) = c;
        }
    }

    void ocr_bboxes_to_charseg(intarray &cseg,narray<rectangle> &bboxes,intarray &segmentation) {
        make_line_segmentation_black(segmentation);
        CHECK_ARG(max(segmentation)<100000);
        intarray counts(max(segmentation)+1,bboxes.length());
        fill(counts,0);
        for(int i=0;i<segmentation.dim(0);i++) for(int j=0;j<segmentation.dim(1);j++) {
            int value = segmentation(i,j);
            if(value==0) continue;
            for(int k=0;k<bboxes.length();k++) {
                rectangle bbox = bboxes[k];
                if(bbox.includes(i,j))
                    counts(value,k)++;
            }
        }
        intarray valuemap(max(segmentation)+1);
        fill(valuemap,0);
        for(int i=1;i<counts.dim(0);i++)
            valuemap(i) = rowargmax(counts,i)+1;
        makelike(cseg,segmentation);
        for(int i=0;i<segmentation.dim(0);i++) for(int j=0;j<segmentation.dim(1);j++) {
            cseg(i,j) = valuemap(segmentation(i,j));
        }
    }

    template <class T>
    void remove_small_components(narray<T> &bimage,int mw,int mh) {
	intarray image;
	copy(image,bimage);
	label_components(image);
	narray<rectangle> rects;
	bounding_boxes(rects,image);
	bytearray good(rects.length());
	for(int i=0;i<good.length();i++) 
	    good[i] = 1;
	for(int i=0;i<rects.length();i++) {
	    if(rects[i].width()<mw && rects[i].height()<mh) {
		// printf("*** %d %d %d\n",i,rects[i].width(),rects[i].height());
		good[i] = 0;
	    }
	}
	for(int i=0;i<image.length1d();i++) {
	    if(!good(image.at1d(i)))
		image.at1d(i) = 0;
	}
	for(int i=0;i<image.length1d();i++)
	    if(!image.at1d(i)) bimage.at1d(i) = 0;
    }
    template void remove_small_components<byte>(narray<byte> &,int,int);
    template void remove_small_components<int>(narray<int> &,int,int);

    template <class T>
    void remove_marginal_components(narray<T> &bimage,int x0,int y0,int x1,int y1) {
	x1 = bimage.dim(0)-x1;
	y1 = bimage.dim(1)-y1;
	intarray image;
	copy(image,bimage);
	label_components(image);
	narray<rectangle> rects;
	bounding_boxes(rects,image);
	bytearray good(rects.length());
	for(int i=0;i<good.length();i++) 
	    good[i] = 1;
	for(int i=0;i<rects.length();i++) {
	    rectangle r = rects[i];
#define lt <
#define ge >
	    if(r.x1 lt x0 || r.x0 ge x1 || r.y1 lt y0 || r.y0 ge y1) {
		// printf("**! %d %d %d\n",i,rects[i].width(),rects[i].height());
	        good[i] = 0;
	    }
	}
	for(int i=0;i<image.length1d();i++) {
	    if(!good(image.at1d(i)))
		image.at1d(i) = 0;
	}
	for(int i=0;i<image.length1d();i++)
	    if(!image.at1d(i)) bimage.at1d(i) = 0;
    }
    template void remove_marginal_components<byte>(narray<byte> &,int,int,int,int);
    template void remove_marginal_components<int>(narray<int> &,int,int,int,int);

    void split_string(narray<strbuf> &components,
                      const char *s,
                      const char *delimiters) {
        components.clear();
        if(!*s) return;
        while(1) {
            const char *p = s;
            while(*p && !strchr(delimiters, *p))
                p++;
            int len = p - s;
            if(len) {
                strbuf &item = components.push();
                item.ensure(len + 1);
                strncpy(item, s, len);
            }
            if(!*p) return;
            s = p + 1;
        }
    }

    void binarize_simple(bytearray &result, bytearray &image) {
        int threshold = (max(image)+min(image))/2;
        makelike(result,image);
        for(int i=0;i<image.length1d();i++)
            result.at1d(i) = image.at1d(i)<threshold ? 0 : 255;
    }
    
    // I think this is by Ambrish --IM
    void runlength_histogram(narray<float> &hist, rectangle line_box, bytearray &img){
        fill(hist,0);
        int runlength = 0;
        int flag = 0;
        for(int j = line_box.y0; j < line_box.y1; j++){       
            for(int k = line_box.x0; k < line_box.x1; k++) {
                if (img(k,j) == 0) {
                    runlength++;
                    flag = 1;
                }
                if (img(k,j) != 0 && flag == 1) {
                    flag = 0;
                    if(runlength < hist.length())
                        hist(runlength)++;
                    runlength = 0;
                }
            }
        }    
    }   

    void runlength_histogram(narray<float> &hist, bytearray &img) {
        CHECK_ARG(background_seems_white(img));
        runlength_histogram(hist, rectangle(0, 0, img.dim(0), img.dim(1)), img);
    }
    
    int find_median(narray<float> &hist){
        int index= 0;
        float partial_sum = 0, sum = 0 ;
        for(int i = 0; i < hist.length(); i++) sum += hist(i);
        for(int j = 0; j < hist.length(); j++) hist(j) /= sum;
        while(partial_sum < 0.5) {
            partial_sum += hist(index);
            index++;
        }
        return index;
    }

    void throw_fmt(const char *format, ...) {
        va_list v;
        va_start(v, format);
        static char buf[1000]; 
        vsprintf(buf, format, v); // XXX: that's unsafe
        va_end(v);
        throw (const char *) buf;
    }
}
