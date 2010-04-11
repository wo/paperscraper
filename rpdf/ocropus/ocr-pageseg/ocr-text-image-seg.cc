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
// File: ocr-text-image-seg.cc
// Purpose: Wrapper class for document zone classification.
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "ocr-text-image-seg.h"

using namespace imgio;
using namespace colib;
using namespace imglib;

namespace ocropus {
    param_string debug_tiseg("debug_tiseg",0,"output result of text image segmentation as png");

    void TextImageSeg::cleanup(bytearray &out, bytearray &in) {
        intarray image;
        autodel<ISegmentPage> segmenter(make_SegmentPageByWCUTS());
        segmenter->segment(image,in);
        remove_nontext_zones(out, image);
        if(debug_tiseg) {
            write_png(stdio(debug_tiseg,"w"), out);
            intarray image_map;
            text_image_map(image_map,in);
            write_png_rgb(stdio("text-image-map.png","w"), image_map);
        }
    }

    void TextImageSeg::get_zone_classes(narray<zone_class> &classes,
                                        rectarray &bboxes,
                                        bytearray &image){

        makelike(classes,bboxes);
        fill(classes, undefined);
    
        autodel<LogReg> logistic_regression(make_LogReg());
        autodel<ZoneFeatures> zone_features(make_ZoneFeatures());

        logistic_regression->load_data();

        int x0, y0, x1, y1, xi, yi;
        floatarray feature;
        int image_width   = image.dim(0);
        int image_height  = image.dim(1);
        bytearray image_tmp;
        for (int i = 0; i < bboxes.length(); i++){
            if(!bboxes[i].area() || bboxes[i].area()>=image_width*image_height)
                continue;
            //bboxes[i].println();
            x0 = ( bboxes[i].x0 > 0 ) ? bboxes[i].x0 : 0; 
            y0 = ( bboxes[i].y0 > 0 ) ? bboxes[i].y0 : 0;
            x1 = ( bboxes[i].x1 < image_width)  ? bboxes[i].x1 : image_width-1;
            y1 = ( bboxes[i].y1 < image_height) ? bboxes[i].y1 : image_height-1;
            if(x1<=x0 || y1<=y0) 
                continue;

            image_tmp.resize(x1 - x0 + 1, y1 - y0 + 1);
            for (xi = x0; xi <= x1; xi++){
                for (yi = y0; yi <= y1; yi++){
                    image_tmp(xi - x0, yi - y0) = image(xi, yi);
                }
            }

            feature.clear();
            zone_features->extract_features(feature, image_tmp);

            //logistic regression 
            classes[i] = logistic_regression->classify(feature);
            
        }
    }

    void TextImageSeg::remove_nontext_zones(bytearray &out_image, intarray &image){
        rectarray bboxes;    
        bounding_boxes(bboxes,image);
        makelike(out_image,image);
        fill(out_image,255); 
        
        int image_width   = image.dim(0);
        int image_height  = image.dim(1);
        bytearray image_bin;
        makelike(image_bin,image);
        for (int x=0; x<image_width; x++){
            for (int y=0; y<image_height ; y++){
                if(image(x,y) == 0x00ffffff)
                    image_bin(x,y) = 255;
                else
                    image_bin(x,y) = 0;
            }
        }

        narray<zone_class> zone_classes;
        get_zone_classes(zone_classes, bboxes, image_bin);

        int x0, y0, x1, y1;
        for (int i = 0; i < bboxes.length(); i++){
            if(zone_classes[i] != text)
                continue;
            x0 = ( bboxes[i].x0 > 0 ) ? bboxes[i].x0 : 0; 
            y0 = ( bboxes[i].y0 > 0 ) ? bboxes[i].y0 : 0;
            x1 = ( bboxes[i].x1 < image_width)  ? bboxes[i].x1 : image_width-1;
            y1 = ( bboxes[i].y1 < image_height) ? bboxes[i].y1 : image_height-1;
            if(x1<=x0 || y1<=y0) 
                continue;

            for(int x=x0;x<x1;x++){
                for(int y=y0;y<y1;y++){
                    out_image(x,y)=image_bin(x,y);
                }
            }
        }
    }

    
    void TextImageSeg::remove_nontext_boxes(rectarray &text_boxes,
                              rectarray &boxes,
                              bytearray &image){
        text_boxes.clear();
        narray<zone_class> zone_classes;
        get_zone_classes(zone_classes, boxes, image);
        for (int i = 0; i < boxes.length(); i++)
            if(zone_classes[i] == text)
                text_boxes.push(boxes[i]);

    }

    int TextImageSeg::get_class_color(zone_class &zone_type){
        int color=0x00ffffff;
        switch(zone_type){
        case math:     color=math_color;     break;
        case logo:     color=logo_color;     break;
        case text:     color=text_color;     break;
        case table:    color=table_color;    break;
        case drawing:  color=drawing_color;  break;
        case halftone: color=halftone_color; break;
        case ruling:   color=ruling_color;   break;
        case noise:    color=noise_color;    break;
        default:       color=0x00ffffff;
        }
        
        return color;
    }

    void TextImageSeg::text_image_map(intarray &out, intarray &in){
        rectarray bboxes;    
        bounding_boxes(bboxes,in);
        makelike(out,in);
        fill(out,0x00ffffff); 
        
        int image_width   = in.dim(0);
        int image_height  = in.dim(1);
        bytearray image_bin;
        makelike(image_bin,in);
        for (int x=0; x<image_width; x++){
            for (int y=0; y<image_height ; y++){
                if(in(x,y) == 0x00ffffff)
                    image_bin(x,y) = 255;
                else
                    image_bin(x,y) = 0;
            }
        }

        narray<zone_class> zone_classes;
        get_zone_classes(zone_classes, bboxes, image_bin);

        int x0, y0, x1, y1;
        for (int i = 0; i < bboxes.length(); i++){
            if(zone_classes[i] == undefined)
                continue;
            x0 = ( bboxes[i].x0 > 0 ) ? bboxes[i].x0 : 0; 
            y0 = ( bboxes[i].y0 > 0 ) ? bboxes[i].y0 : 0;
            x1 = ( bboxes[i].x1 < image_width)  ? bboxes[i].x1 : image_width-1;
            y1 = ( bboxes[i].y1 < image_height) ? bboxes[i].y1 : image_height-1;
            if(x1<=x0 || y1<=y0) 
                continue;

            int color = get_class_color(zone_classes[i]);

            for(int x=x0;x<x1;x++){
                for(int y=y0;y<y1;y++){
                    if(!image_bin(x,y))
                        out(x,y)=color;
                }
            }
        }

    }

    void TextImageSeg::text_image_map(intarray &out, bytearray &in){
        intarray image;
        autodel<ISegmentPage> segmenter(make_SegmentPageByWCUTS());
        segmenter->segment(image,in);
        text_image_map(out, image);
      
    }


    ICleanupBinary *make_TextImageSeg() {
        return new TextImageSeg();
    }

}

