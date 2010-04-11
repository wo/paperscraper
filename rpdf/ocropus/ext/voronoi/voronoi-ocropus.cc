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
// File: voronoi-ocropus.cc
// Purpose: Wrapper class for voronoi code
//
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "imgio.h"
#include "imglib.h"
#include "ocr-utils.h"
#include "voronoi-ocropus.h"
#include "defs.h"
#include "function.h"

#define MAXVAL 256

using namespace colib;
using namespace imgio;
using namespace imglib;
using namespace voronoi;

namespace ocropus {
    
    static void bytearray2img(ImageData *imgd, bytearray &image){
        int width  = image.dim(0);
        int height = image.dim(1);

        if((imgd->image=(char *)malloc(width*height))==NULL){
            fprintf(stderr,"bytearray2imgd: not enough memory for image\n");
            exit(1);
        }
        /* setting dimension */
        imgd->imax=width;
        imgd->jmax=height;

        for(int y=0; y<height; y++){
            for(int x=0; x<width; x++){
               imgd->image[x+y*width] = image(x,y);
            }
        }

        /* cleaning the right edge of the image */
        char            emask = 0x00;
        unsigned long   h=imgd->jmax;
        /*for( i = 0 ; i < w%BYTE ; i++)
          emask|=(0x01 << (BYTE-i-1));*/
        for(int j = 0 ; j < h ; j++)
            *((imgd->image)+(j+1)*imgd->imax-1)&=emask;
        
        imgd->imax = image.dim(0)*8;

    }

    static void img2bytearray(intarray &image, ImageData *imgd){
        int width  = imgd->imax;
        int height = imgd->jmax;
        image.resize(width,height);

        for(int y=0; y<height; y++){
            for(int x=0; x<width; x++){
               unsigned char val = imgd->image[x+y*width];
               if(val == WHITE)
                   image(x,height-y-1) = 0x00ffffff;
               else if(val == BLACK)
                   image(x,height-y-1) = 0;
               else
                   image(x,height-y-1) = val;
            }
        }

    }

    static void byte2bit(bytearray &cimg, bytearray &in_img){
        // compress to 1bit/pixel and invert as required by voronoi code
        bytearray img;
        copy(img,in_img);
        int width  = in_img.dim(0);
        int height = in_img.dim(1);

        for(int x=0; x<width; x++)
            for(int y=0; y<height; y++)
                if(img(x,y)>128)    
                    img(x,y)=0;
                else
                    img(x,y)=1;
  
        unsigned char b0,b1,b2,b3,b4,b5,b6,b7;
        cimg.resize((img.dim(0)>>3),img.dim(1));
        for(int y=0,yi=height-1; y<height; y++,yi--)
            for(int x=0,xi=0, width=cimg.dim(0); (x<width && xi+7<img.dim(0)); x++, xi+=8){
                b7 = (img(xi,yi)<<7)   & 0x80;
                b6 = (img(xi+1,yi)<<6) & 0x40;
                b5 = (img(xi+2,yi)<<5) & 0x20;
                b4 = (img(xi+3,yi)<<4) & 0x10;
                b3 = (img(xi+4,yi)<<3) & 0x08;
                b2 = (img(xi+5,yi)<<2) & 0x04;
                b1 = (img(xi+6,yi)<<1) & 0x02;
                b0 = (img(xi+7,yi)<<0) & 0x01;
                cimg(x,y)= b0| b1| b2| b3| b4| b5| b6| b7 ;
            }
    }

    void SegmentPageByVORONOI::segment(intarray &out_image,bytearray &in_image){

        ImageData imgd_in,imgd_out;
        bytearray in_bitimage;
        intarray voronoi_diagram_image;

        byte2bit(in_bitimage,in_image);

        bytearray2img(&imgd_in,in_bitimage);

        voronoi_colorseg(&imgd_out,&imgd_in);

        img2bytearray(voronoi_diagram_image,&imgd_out);

        for(int i=0; i<voronoi_diagram_image.length1d(); i++){
            if(voronoi_diagram_image.at1d(i) == 0x00ffffff)
                voronoi_diagram_image.at1d(i) = 1;
            else
                voronoi_diagram_image.at1d(i) = 0;
        }

        label_components(voronoi_diagram_image,false);
        simple_recolor(voronoi_diagram_image);

        makelike(out_image,in_image);
        //fprintf(stderr,"%d %d\n",in_image.length1d(),voronoi_diagram_image.length1d());
        for(int i=0; i<in_image.length1d(); i++){
            if(in_image.at1d(i) == 0)
                out_image.at1d(i) = voronoi_diagram_image.at1d(i);
            else
                out_image.at1d(i) = 0x00ffffff;
        }
        //copy(out_image,voronoi_diagram_image);
    }

    ISegmentPage *make_SegmentPageByVORONOI() {
        return new SegmentPageByVORONOI();
    }

} //namespace
