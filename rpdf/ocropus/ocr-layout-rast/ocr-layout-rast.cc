// -*- C++ -*-

// Copyright 2006-2008 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
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
// Project: OCRopus
// File: ocr-layout-rast.cc
// Purpose: perform layout analysis by RAST
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include <time.h>
#include "ocr-layout-rast.h"

using namespace imgio;
using namespace imglib;
using namespace colib;

namespace ocropus {

    const int LEFT_ALIGNED   = 1;
    const int RIGHT_ALIGNED  = 2;
    const int CENTER_ALIGNED = 3;
    const int JUSTIFIED      = 4;
    const int NOT_ALIGNED    = 0;

    param_string debug_segm("debug_segm",0,"output segmentation file");
    param_int  debug_layout("debug_layout",0,"print the intermediate results to stdout");

    SegmentPageByRAST::SegmentPageByRAST(){
        column_threshold = 0.6;
        id = 0;
    }

    line::line(TextLine &tl):
        c(tl.c), m(tl.m), d(tl.d), 
        start(tl.bbox.x0), end(tl.bbox.x1), top(tl.bbox.y0), bottom(tl.bbox.y1),
        istart(tl.bbox.x0), iend(tl.bbox.x1), xheight(tl.xheight){
    }

    TextLine line::getTextLine(){
        TextLine tl;
        tl.c = c;
        tl.m = m;
        tl.d = d;
        tl.xheight = (int)xheight;
        //rectangle r((int)start, (int)top, (int)end, (int)bottom);
        rectangle r((int)istart, (int)top, (int)iend, (int)bottom);
        tl.bbox = r;
        return tl;
    }


    //Assuming horizontal lines with slope in the interval [-0.05, 0.05]
    static int wbox_intersection(line l, rectangle wbox){
        
        float y = l.m * wbox.xcenter() + l.c;
        return ( (y > wbox.y0) && (y < wbox.y1) );
    }
    
    static void extend_lines(narray<line> &lines, rectarray &wboxes,
                             int image_width){

        int num_lines = lines.length();
        int num_wboxes = wboxes.length();
        
        for(int i = 0; i<num_lines; i++){
            float new_start = 0;
            float new_end = image_width-1;
            for(int j = 0; j<num_wboxes; j++){
                if(wbox_intersection(lines[i], wboxes[j])){
                    if(wboxes[j].x0 <= lines[i].start)
                        new_start = (new_start > wboxes[j].x1) ? new_start : wboxes[j].x1;
                    else
                        new_end = (new_end   < wboxes[j].x0) ? new_end   : wboxes[j].x0;
                }
            }
            lines[i].start = (lines[i].start > new_start) ? new_start : lines[i].start;
            lines[i].end = (lines[i].end   < new_end  ) ? new_end   : lines[i].end  ;
            //printf("%.0f %.0f %.0f %.0f \n",lines[i].start,lines[i].top,lines[i].end,lines[i].bottom);
        }
    }

    static void paint_line(intarray &image, line l){
        int width=image.dim(0);
        int height=image.dim(1);
        float y;
        float slope = l.m;
        float y_intercept = l.c;
        float descender = l.d;
        int   start =  (l.start>0) ? (int) l.start : 0;
        int   end   =  (l.end  <width) ? (int) l.end   : width;
        int yl, yh, dl, dh;
        bool baseline_only = false;
        //for horizontal lines
    
        for(int x=start;x<end;x++){
            y = slope * x + y_intercept;
            yl = (int) y;
            yh = yl +1;
            dl = (int) (y - descender); // Origin is in bottom left corner
            dh = dl +1;
            if( (yl >= 0) && (yl < height) )
                image(x,yl) &= 0xff0000ff;
            if( (yh >= 0) && (yh < height) )
                image(x,yh) &= 0xff0000ff;
            if(!baseline_only){
                if( (dl >= 0) && (dl < height) )
                    image(x,dl) &= 0xff00ffff;
                if( (dh >= 0) && (dh < height) )
                    image(x,dh) &= 0xff00ffff;
            }
        }
        
    }

    //Paint the given rectangle with yellow color.
    //The color format is xRGB, which means the hexadecimal no. 0x00FF0000 is red.
    static void paint_box(intarray &image, rectangle b, int color){
        int width=image.dim(0);
        int height=image.dim(1);
        int left, top, right, bottom;
        left   = (b.x0<0) ? 0 : b.x0;
        top    = (b.y0<0) ? 0 : b.y0;
        right  = (b.x1>=width) ? width-1 : b.x1;
        bottom = (b.y1>=height) ? height-1 : b.y1;

        if(right <= left || bottom <= top) return;

        for(int x= left;x< right;x++){
            for(int y= top;y< bottom;y++){
                image(x,y)&=color;
            }
        }
        
    }

    //Paint only the box border
    static void paint_box_border(intarray &image, rectangle b, int color){
        int width=image.dim(0);
        int height=image.dim(1);
        int left, top, right, bottom;
       
        left   = (b.x0<0)  ? 0   : b.x0;
        top    = (b.y0<0)  ? 0   : b.y0;
        right  = (b.x1>=width) ? width-1 : b.x1;
        bottom = (b.y1>=height) ? height-1 : b.y1;

        if(right <= left || bottom <= top) return;

        int x,y;
        for(x=left;x<=right;x++){ image(x,top)     &=color; }
        for(x=left;x<=right;x++){ image(x,bottom)  &=color; }
        for(y=top;y<=bottom;y++){ image(left,y)    &=color; }
        for(y=top;y<=bottom;y++){ image(right,y)   &=color; }
        
    }

    static void connect_line_centers(intarray &image, line a, line b){
        int width=image.dim(0);
        float x1 = (a.start + a.end)/2.0;
        float x2 = (b.start + b.end)/2.0;
        float y1 = a.m * x1 + a.c ;
        float y2 = b.m * x2 + b.c ;

        if (y2==y1) return;
        float slope_inverse = ((y2 - y1) != 0)? (x2 - x1)/(y2 - y1) : HUGE_VAL;

        //if (x1 > x2) swap(x1, x2);
        //if (y1 > y2) swap(y1, y2);

        int linewidth = 1; //actual line width = 2*linewidth +1
        int thickness  = 2 * linewidth + 1;
        int yoffset = 10; //Height of arrow head

        float x,y;
        if(y1 < y2){
            for (y = y1; y<= y2; y++){
                x = slope_inverse * (y - y1) + x1;
                x = (x <  2*linewidth)   ? 2*linewidth : x;
                x = (x >= width-2*linewidth) ? width-2*linewidth-1 : x;
                for(int i = 0; i < thickness; i++)
                    image((int)x-linewidth+i ,(int)y) &= 0xffff00ff;
                if (y >= y2 - yoffset){
                    for(int i = 0; i < 2*thickness; i++)
                        image((int)x-2*linewidth+i ,(int)y) &= 0xffff00ff;
                }
            }
        }else{
            for (y = y1; y>= y2; y--){
                x = slope_inverse * (y - y1) + x1;
                x = (x <  2*linewidth)   ? 2*linewidth : x;
                x = (x >= width-2*linewidth) ? width-2*linewidth-1 : x;
                for(int i = 0; i < thickness; i++)
                    image((int)x-linewidth+i ,(int)y) &= 0xffff00ff;
                if (y <= y2 + yoffset){
                    for(int i = 0; i < 4*thickness; i++)
                        image((int)x-4*linewidth+i ,(int)y) &= 0xffff0000;
                }
            }
        }
    }

    static void paint_reading_order(intarray &image, narray<line> &lines_ordered){
        int size = lines_ordered.length();
        for(int i=0; i<size-1; i++){
            connect_line_centers(image, lines_ordered[i], lines_ordered[i+1]);
        }
    }

    void SegmentPageByRAST::segmentInternal(intarray &visualization, intarray &image,bytearray &in_not_inverted, bool need_visualization) {

        //float startTime = clock()/float(CLOCKS_PER_SEC);
        const int zero   = 0;
        const int yellow = 0x00ffff00;
        bytearray in;
        copy(in, in_not_inverted);
        make_page_binary_and_black(in);
        //fprintf(stderr,"Time elapsed (autoinvert): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);
        
        // Do connected component analysis
        intarray charimage;
        copy(charimage,in);
        label_components(charimage,false);
        //fprintf(stderr,"Time elapsed (label_components): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);

        // Clean non-text and noisy boxes and get character statistics
        rectarray bboxes;
        bounding_boxes(bboxes,charimage);
        if(bboxes.length()==0){
            makelike(image,in);
            fill(image,0x00ffffff);
            return ;
        }
        //fprintf(stderr,"Time elapsed (bounding_boxes): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);
        autodel<CharStats> charstats(make_CharStats());
        charstats->get_char_boxes(bboxes);
        charstats->calc_char_stats();
        if(debug_layout>=2){
            charstats->print();
        }
        //fprintf(stderr,"Time elapsed (charstats): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);

        // Compute Whitespace Cover
        autodel<WhitespaceCover> whitespaces(make_WhitespaceCover(0,0,in.dim(0),in.dim(1)));
        rectarray whitespaceboxes;
        whitespaces->compute(whitespaceboxes,charstats->char_boxes);
        //fprintf(stderr,"Time elapsed (whitespaces): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);

        // Find column separators
        autodel<ColSeparators> gutters(make_ColSeparators());
        rectarray columns,colcandidates;
        gutters->find_gutters(colcandidates,whitespaceboxes,*charstats);
        gutters->filter_overlaps(columns,colcandidates);
        if(debug_layout){
            for(int i=0; i<columns.length();i++){
                printf("%d %d %d %d\n",columns[i].x0,columns[i].y0,
                       columns[i].x1,columns[i].y1);
            }
        }
        //fprintf(stderr,"Time elapsed (gutters): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);

        // Extract textlines
        autodel<CTextlineRAST> ctextline(make_CTextlineRAST());
        narray<TextLine> textlines;
        ctextline->min_q     = 2.0; // Minimum acceptable quality of a textline
        ctextline->min_count = 2;   // ---- number of characters in a textline
        ctextline->min_length= 30;  // ---- length in pixels of a textline
        ctextline->extract(textlines,columns,charstats);
        rosort(textlines,columns,*charstats);
        //fprintf(stderr,"Time elapsed (ctextline): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);

        //rectarray paragraphs;
        rectarray textcolumns;
        //ctextline->grouppara(paragraphs,textlines,charstats);
        getcol(textcolumns,textlines,columns);
        color(image,in,textlines,textcolumns);
        //fprintf(stderr,"Time elapsed (find-columns): %.3f \n",(clock()/float(CLOCKS_PER_SEC)) - startTime);
//         if(debug_layout){
//             for(int i=0; i<textlines.length();i++)
//                 textlines[i].print();
//             for (int i=0; i<textcolumns.length();i++)
//                 textcolumns[i].println();
//         }
        replace_values(image,zero,yellow);
        if(need_visualization) {
            visualizeLayout(visualization, in_not_inverted, textlines, columns, *charstats);
        }
    }

    void SegmentPageByRAST::segment(intarray &result, bytearray &in_not_inverted) {
        intarray debug_image;
        if(debug_segm) {
            segmentInternal(debug_image, result, in_not_inverted, true);
            write_png_rgb(stdio(debug_segm,"w"), debug_image);
        } else {
            segmentInternal(debug_image, result, in_not_inverted, false);
        }
    }

    void SegmentPageByRAST::visualize(intarray &result, bytearray &in_not_inverted) {
        intarray segmentation;
        segmentInternal(result, segmentation, in_not_inverted, true);
    }

    void SegmentPageByRAST::visualizeLayout(intarray &debug_image,
                                            bytearray &in_not_inverted,
                                            narray<TextLine> &textlines,
                                            rectarray &columns, 
                                            CharStats &charstats) {
        makelike(debug_image,in_not_inverted);
        int v0 = min(in_not_inverted);
        int v1 = max(in_not_inverted);
        int threshold = (v1+v0)/2;
        for(int i=0; i<in_not_inverted.length1d(); i++)
            debug_image.at1d(i)=int((in_not_inverted.at1d(i)<threshold)?0:0x00ffffff);
        narray<line> lines;
        for(int i = 0; i<textlines.length(); i++)
            lines.push(line(textlines[i]));
        if(lines.length() > 1){
            for(int i=0; i<columns.length(); i++){
                paint_box(debug_image,columns[i],0x00ffff00);
                paint_box_border(debug_image,columns[i],0x0000ff00);
                
            }
            for(int i=0,l=lines.length();i<l;i++){
                paint_line(debug_image,lines[i]);
            }
            if(columns.length()){
                extend_lines(lines, columns, charstats.img_width);
            }
            paint_reading_order(debug_image,lines);
        }
    }
    

    ISegmentPage *make_SegmentPageByRAST() {
        return new SegmentPageByRAST();
    }
    
    static inline bool x_overlap(line a, line b){
        return ( (a.end >= b.start) && (b.end >= a.start) );
    }
    
    static bool separator_segment_found(line a, line b, narray<line> &lines){
        int lines_length = lines.length();
        float y_min = (a.c < b.c) ? a.c : b.c;
        float y_max = (a.c > b.c) ? a.c : b.c;
        
        for(int i = 0; i<lines_length; i++)
            if( x_overlap(lines[i],a) && x_overlap(lines[i],b) )
                if( (lines[i].c > y_min) && (lines[i].c < y_max) )
                    return true;
        
        return false;
        
    }
    
    static void construct_graph(narray<line> &lines, narray<bool> &lines_dag){
        //lines_dag(i,j) = 1 iff there is a directed edge from i to j
        int graph_length = lines.length();
        
        for(int i = 0; i<graph_length; i++){
            for(int j = i; j<graph_length; j++){
                
                if(i == j){ lines_dag(i,j) = 1; continue; }
                
                if( x_overlap(lines[i],lines[j]) ){
                    //assuming parallel horizontal lines and page origin and bottom left corner
                    if(lines[i].top > lines[j].top) { lines_dag(i,j) = 1; }
                    else { lines_dag(j,i) = 1; }
                }
                
                else{
                    if( separator_segment_found(lines[i],lines[j],lines) )        continue;
                    else if(lines[i].end <= lines[j].start)  { lines_dag(i,j) = 1; }
                    else  { lines_dag(j,i) = 1; }
                }
            }
        }
    }
    
    void SegmentPageByRAST::visit(int k, narray<bool> &lines_dag){
        int size = lines_dag.dim(0);
        val(k) = ++id;
        for (int i = 0; i< size; i++){
            if(lines_dag(k,i) != 0)
                if(val(i) == 0)
                    visit(i, lines_dag);
        }
        //cout << k << "\t";
        ro_index.push(k);
    }
    
    void SegmentPageByRAST::depth_first_search(narray<bool> &lines_dag){
        //void visit (int k);
        int size = lines_dag.dim(0);
        val.resize(size);
        fill(val,false);
        for (int k = 0; k< size; k++)
            if (val(k) == 0)
                visit(k, lines_dag);
    }
    
    void SegmentPageByRAST::rosort(narray<TextLine> &textlines,
                                   rectarray &columns,
                                   CharStats &charstats){
        id = 0;
        val.clear();
        ro_index.clear();
        narray<line> lines;
        for(int i = 0; i<textlines.length(); i++)
            lines.push(line(textlines[i]));

        if(lines.length() <= 1){
            return;
        }
        if(columns.length()){
            sort_boxes_by_x0(columns);
            extend_lines(lines, columns, charstats.img_width);
        }

        // Determine reading order
        narray<bool> lines_dag; // Directed acyclic graph of lines
        lines_dag.resize( lines.length(), lines.length() );
        fill(lines_dag,false);
        
        construct_graph(lines, lines_dag);
        depth_first_search(lines_dag);
        int size = ro_index.length();
        //"\nNumber of connected lines = " << size <<"\n";
        textlines.clear();
        for(int i = 1; i <= size; i++){
            textlines.push(lines[ro_index[size-i]].getTextLine());
        }
    }
    
    static bool new_column(rectangle current, rectangle previous){
        if(current.y0 > previous.y1){return true;}
        return false;
    }
    
    static void getbbox(rectangle &bbox,rectarray &bboxes){
        //first copying into arrays for x0,x1,y0,y1
        bbox = rectangle();
        for(int i = 0; i<bboxes.length();i++){
            bbox.include(bboxes[i]);
        }
    }
        
    static int alignment(bool left, bool right, bool center){
        if(left == true   &&  right == true   && center == true)  { return JUSTIFIED;}
        if(left == false  &&  right == false  && center == true)  { return CENTER_ALIGNED;}
        if(left == true   &&  right == false  && center == false) { return LEFT_ALIGNED;}
        if(left == false  &&  right == true   && center == false) { return RIGHT_ALIGNED;}
        return NOT_ALIGNED;
    }

    static int getrelalign(rectangle &current,rectangle &previous){
        bool left = false;
        bool right = false;
        bool center = false;
        int align_range = 10;
        if(current.x0<(previous.x0 + align_range) && current.x0>(previous.x0-align_range))
            {left = true;}
        

        if(current.x1<(previous.x1+align_range) && current.x1>(previous.x1-align_range))
            {right = true;}
        
        if(current.xcenter() < (previous.xcenter() + align_range) && 
           current.xcenter()  >(previous.xcenter() - align_range))
            {center = true;}
        
        return alignment(left, right, center);
    }

    static void getalign(objlist< narray <int> > &tempalign, 
                         objlist< narray <rectangle> > &temppara){
        narray<int> talign;
        rectangle current,previous;
        for(int i = 0;i<temppara.length();i++){
            talign.push(NOT_ALIGNED);
            previous = temppara[i][0];
            for(int j = 1;j<temppara[i].length();j++){
                current = temppara[i][j];
                talign.push(getrelalign(current,previous));
                previous = current;
            }
            move(tempalign.push(),talign);
        }
    }
               
    static void merge_single_line_paras(objlist<rectarray > &amcolumns,
                                        objlist<rectarray > &finalpara,
                                        objlist<narray<int> > &finalalign){
        objlist< narray <int> > amalignment;
        rectarray current_tpara;
        narray<int> current_talign;
        
        for(int i = 0;i<finalpara.length();i++){
            if(finalpara[i].length() == 1 && finalalign[i][0] == 1){
                if((amcolumns.length()-1) >= 0){
                    amcolumns[amcolumns.length()-1].push(finalpara[i][0]);
                    amalignment[amcolumns.length()-1].push(finalalign[i][0]);
                }
            }else if(finalpara[i].length() == 2 && finalalign[i][0] == 0 &&
                     finalalign[i][1] == 2 && (i+1)<finalpara.length()){
                current_tpara.push(finalpara[i][0]);
                current_tpara.push(finalpara[i][1]);
                current_talign.push(finalalign[i][0]);
                current_talign.push(finalalign[i][1]);
                for(int j = 0;j<finalpara[(i+1)].length();j++){
                    current_tpara.push(finalpara[i+1][j]);
                    current_talign.push(finalalign[i+1][j]);
                }
                move(amcolumns.push(),current_tpara);
                move(amalignment.push(),current_talign);
                i = i+1;
            }else{
                copy(current_tpara,finalpara[i]);
                move(amcolumns.push(),current_tpara);
                copy(current_talign,finalalign[i]);
                move(amalignment.push(),current_talign);
            }
        }
    }

    static bool matches_previous(int previous_alignment, int tempalign){
        return (previous_alignment == 0 && tempalign != 0) ||
            (previous_alignment != 0 && tempalign == previous_alignment);
    }
      
    static bool not_matches_previous(int previous_alignment, int tempalign){
        return (previous_alignment == 0 && tempalign == 0) ||
            (previous_alignment != 0 && tempalign != previous_alignment);
    }
      
    void SegmentPageByRAST::grouppara(rectarray &paragraphs ,
                                      narray<TextLine> &textlines,
                                      CharStats &charstats){

        if(textlines.length() == 0)
            return ;
        rectangle current,previous;
        //initializing previous
        objlist< narray <rectangle> > temppara;
        objlist< narray <int> > tempalign;
        objlist< narray <rectangle> > finalpara;
        objlist< narray <int> > finalalign;
        rectarray current_tpara;
        narray<int> current_talign;
        
        
        //since the textlines are sorted we group them on the basis of y
        //coordinate and gaps between them. 
 
        previous = textlines[0].bbox;
        current_tpara.push(previous);
        for(int i = 1;i<textlines.length();i++){
            current = textlines[i].bbox;
            if(!new_column(current,previous) && 
               (previous.y0-current.y1 < 2*charstats.line_spacing)){
                current_tpara.push(current);
                previous = current;
            }else{
                move(temppara.push(),current_tpara);
                current_tpara.push(current);
                previous = current;
            }
            if(i+1 == textlines.length()){move(temppara.push(),current_tpara);}
        }
        
        // now get alignment for the temporary paragraphs
    
        getalign(tempalign,temppara);
        
        //now divide into groups where alignment changes
        
        int previous_alignment;
        for(int i = 0;i<temppara.length();i++){
            current_tpara.push(temppara[i][0]);
            current_talign.push(tempalign[i][0]);
            previous_alignment = tempalign[i][0];
            for(int j = 1;j<temppara[i].length();j++){
                if(matches_previous(previous_alignment, tempalign[i][j])){
                    current_tpara.push(temppara[i][j]);
                    current_talign.push(tempalign[i][j]);
                    previous_alignment = tempalign[i][j];
                }
                if(not_matches_previous(previous_alignment, tempalign[i][j])){
                    move(finalpara.push(),current_tpara);
                    move(finalalign.push(),current_talign);
                    current_tpara.push(temppara[i][j]);
                    current_talign.push(tempalign[i][j]);
                    previous_alignment = tempalign[i][j];
                }
            }
            move(finalpara.push(),current_tpara);
            move(finalalign.push(),current_talign);
        }
        
        
        //now  merge single and double lines 
        objlist< narray <rectangle> > amcolumns;
        merge_single_line_paras(amcolumns,finalpara,finalalign);
       
        // get the final bounding boxes of the paragraphs
        rectangle temp;
        for(int i = 0; i<amcolumns.length();i++){
            getbbox(temp,amcolumns[i]);
            paragraphs.push(temp);
        }
    }
    
    static float getoverlap(rectangle current,rectangle previous){
        int   intersection = (min(current.x1,previous.x1)-max(current.x0,previous.x0));
        float width_sum = (current.x1-current.x0)+(previous.x1-previous.x0);
        if(width_sum)
            return (2*intersection)/ width_sum;
        else
            return 0;
    }
    
    
    
    
    void SegmentPageByRAST::getcol(rectarray &columns,
                                   rectarray &paragraphs){
        objlist< rectarray > tempcol;
        objlist< narray<float> > floatcol;
        rectarray temp;
        narray<float> temp1;
        rectarray probablecol;
        rectangle previous;
        rectangle current;
        rectangle tempt;

        if(paragraphs.length() == 0)
                     return ;
        
        //first separating on the basis of y coordinate
        previous = paragraphs[0];
        temp.push(previous);
        temp1.push(1.0);
        for(int i = 1;i<paragraphs.length();i++){
            current = paragraphs[i];
            if(current.y1 > previous.y1){
                move(tempcol.push(),temp);
                move(floatcol.push(),temp1);
                temp.push(current);
                temp1.push(getoverlap(current,previous));
                previous = current;
            }else{
                temp1.push(getoverlap(current,previous));
                temp.push(current);
                previous = current;
            }
        }
        move(tempcol.push(),temp);
        move(floatcol.push(),temp1);

        // now grouping on the basis of overlap and getting bounding boxes of the columns
        
        FILE *colfile = fopen("columns.dat","w");
        for(int i=0; i<tempcol.length(); i++){
                probablecol.push(tempcol[i][0]);
            for(int j = 1;j<tempcol[i].length();j++){
                if(floatcol[i][j]>column_threshold){
                    probablecol.push(tempcol[i][j]);
                }else{
                    getbbox(tempt,probablecol);
                    columns.push(tempt);
                    probablecol.dealloc();
                    probablecol.push(tempcol[i][j]);
                }
            }
            getbbox(tempt,probablecol);
            probablecol.dealloc();
            columns.push(tempt);
            tempt.println(colfile);
        }
        fclose(colfile);
    }

    void SegmentPageByRAST::getcol(rectarray &textcolumns,
                                   narray<TextLine> &textlines,
                                   rectarray &gutters){

        if(!textlines.length())  return;
        if(!gutters.length()){
            rectangle column = rectangle();
            for(int i=0; i<textlines.length(); i++)
                column.include(textlines[i].bbox);
            textcolumns.push(column);
            return;
        }

        rectangle column = rectangle(textlines[0].bbox);
        rectangle tempcolumn =
        rectangle(textlines[0].bbox.dilated_by(-10,-2,-10,-2));
        for(int i=1; i<textlines.length(); i++){
            tempcolumn.include(textlines[i].bbox.dilated_by(-10,-2,-10,-2));
            bool intersects_gutter = false;
            bool gutter_penetrating_from_below = false;
            bool gutter_penetrating_from_above = false;
            for(int j=0; j<gutters.length(); j++){
                point top    = point(gutters[j].xcenter(),gutters[j].y1) ;
                point bottom = point(gutters[j].xcenter(),gutters[j].y0) ;
                if(tempcolumn.overlaps(gutters[j])){
                    intersects_gutter = true;
                    if(textlines[i].bbox.contains(top))
                        gutter_penetrating_from_below = true;
                    if(textlines[i].bbox.contains(bottom))
                        gutter_penetrating_from_above = true;
                    break;
                }
            }
            if(intersects_gutter && !gutter_penetrating_from_below){
                textcolumns.push(column);
                column = rectangle(textlines[i].bbox);
                if(!gutter_penetrating_from_above)
                    tempcolumn=rectangle(textlines[i].bbox.dilated_by(-10,-2,-10,-2));
                else
                    tempcolumn=rectangle();
            } else{
                column.include(textlines[i].bbox);
            }
        }
    }

    void SegmentPageByRAST::color(intarray &image,bytearray &in, 
                                  narray<TextLine> &textlines,
                                  rectarray &textcolumns){
        int color;
        int column_num = 0x00010000;
        makelike(image,in);
        //Comment out this loop when the input image is not inverted
        for(int i = 0, l = image.length1d(); i<l; i++){
            if(!in.at1d(i))
                in.at1d(i) = 0xff;
            else
                in.at1d(i) = 0;
        }
        for(int i = 0, l = image.length1d(); i<l; i++){
            if(!in.at1d(i))
                image.at1d(i) = 0;
            else
                image.at1d(i) = 0x00ffffff;
        }
        color = 1;
        // Limit the number of text columns to what can actually be encoded (30)
        int MAX_COLS = 30;
        int num_cols = (textcolumns.length() < MAX_COLS)?textcolumns.length():MAX_COLS;
        if(num_cols!=textcolumns.length()) {
            fprintf(stderr,"\nWarning: Too many text columns: %d\n", textcolumns.length());
            fprintf(stderr,"         Max # of text columns: %d\n\n", MAX_COLS);
        }
        for(int i = 0, l = textlines.length(); i<l; i++){
            bool changed = false;
            rectangle r = textlines[i].bbox;
            int j;
            for(j = 0; j<num_cols; j++)
                if(textcolumns[j].includes(r))
                    break;
            column_num = (j+1)<<16;
            for(int x = r.x0, x1 = r.x1; x<x1; x++){
                for(int y = r.y0, y1 = r.y1; y<y1; y++){
                    if(!in(x,y) && !image(x,y)) {
                        image(x,y) = (color|column_num);
                        changed = true;
                    }
                }
            }
            if(changed)
                color++;
        }
    }

    void visualize_segmentation_by_RAST(colib::intarray &result, colib::bytearray &in_not_inverted) {
        SegmentPageByRAST s;
        s.visualize(result, in_not_inverted);
    }
}

