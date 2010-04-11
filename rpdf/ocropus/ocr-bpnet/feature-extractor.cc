// Copyright 2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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
// Project: ocr-bpnet
// File: feature-extractor.h
// Purpose: feature extractor class
// Responsible: kapry
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "feature-extractor.h"
#include "imglib.h"
#include "ocr-utils.h"

using namespace colib;
using namespace imglib;
using namespace ocropus;

#define DIM_X 10
#define DIM_Y 10
#define STANDARD_Y 40
#define MAX_REL_SIZE 1.5
#define IN(i,j,image) ((i>=0)&&(i<(image).dim(0))&&(j>=0)&&(j<(image).dim(1)))
#define IN_BOX(i,j,box) ((i>=(box).x0)&&(i<=(box).x1)&&(j>=(box).y0)&&(j<=(box).y1))

// if boundary pixel: DO delete...
// WE ASSUME A BINARY IMAGE!
static int n_x[8] = {0,1,1,1,0,-1,-1,-1};
static int n_y[8] = {1,1,0,-1,-1,-1,0,1};

// _____________________________________________________________________________

void embed_img_with_white(bytearray &out,bytearray &in,int size) {
    out.resize(in.dim(0)+2*size,in.dim(1)+2*size);
    fill(out,255);
    for (int i=0;i<in.dim(0); i++)
        for (int j=0;j<in.dim(1); j++)
            out(i+size,j+size) = in(i,j);
}

inline float get(bytearray &image,int x,int y) {
    if(IN(x,y,image)) return image(x,y);
    else return 255;
}

inline bool set(bytearray &img, int x, int y, byte val) {
    if (IN(x,y,img)) {
        img(x,y)= val;
        return true;
    }
    else return false;
}

rectangle find_one_box(bytearray &img) {
    // a check for img.dim([0,1]) > 0 would be nice!
    int xmin=img.dim(0)-1,xmax=0,ymin=img.dim(1)-1,ymax=0;
    for (int i=0; i<img.dim(0); i++)
        for (int j=0; j<img.dim(1); j++)
            if (img(i,j)==0) {
                xmin=i<xmin?i:xmin;
                ymin=j<ymin?j:ymin;
                xmax=i>xmax?i:xmax;
                ymax=j>ymax?j:ymax;
            }
    return rectangle(xmin,ymin,max(xmax,1),max(ymax,1));
}

rectangle find_one_box(bytearray &img, int T) {
    int xmin=img.dim(0)-1,xmax=0,ymin=img.dim(1)-1,ymax=0;
    for (int i=0; i<img.dim(0); i++) {
        for (int j=0; j<img.dim(1); j++) {
            if (img(i,j)<T) {
                xmin=i<xmin?i:xmin;
                ymin=j<ymin?j:ymin;
                xmax=i>xmax?i:xmax;
                ymax=j>ymax?j:ymax;
            }
        }
    }
    return rectangle(xmin,ymin,max(xmax,1),max(ymax,1));
}

float interpolate_bilinear_from_gray(bytearray &img,float x,float y) {
    int valll, valhl, vallh, valhh;
    int xl = (int)x;
    int yl = (int)y;
    float u = x - xl;
    float v = y - yl;
    float coll, cohl, colh, cohh;
    coll = (1-u)*(1-v);
    cohl = u*(1-v);
    colh = (1-u)*v;
    cohh = u*v;

    if (IN(xl,yl,img)) valll = img(xl,yl);
    else valll = 255;
    if (IN(xl,yl+1,img)) vallh = img(xl,yl+1);
    else vallh = 255;
    if (IN(xl+1,yl,img)) valhl = img(xl+1,yl);
    else valhl = 255;
    if (IN(xl+1,yl+1,img)) valhh = img(xl+1,yl+1);
    else valhh = 255;

    return coll*valll + cohl*valhl + colh*vallh + cohh*valhh;
}

// T Threshold, z.B. 128.
byte interpolate_bin(bytearray &img,float x,float y,
                     byte T) {

    byte valll, valhl, vallh, valhh;
    int xl = (int)x;
    int yl = (int)y;
    float u = x - xl;
    float v = y - yl;
    float coll, cohl, colh, cohh;
    coll = (1-u)*(1-v);
    cohl = u*(1-v);
    colh = (1-u)*v;
    cohh = u*v;

    if (IN(xl,yl,img)) valll = img(xl,yl);
    else valll = 0;
    if (IN(xl,yl+1,img)) vallh = img(xl,yl+1);
    else vallh = 0;
    if (IN(xl+1,yl,img)) valhl = img(xl+1,yl);
    else valhl = 0;
    if (IN(xl+1,yl+1,img)) valhh = img(xl+1,yl+1);
    else valhh = 0;

    if (valll > 0) valll = 255;
    if (vallh > 0) vallh = 255;
    if (valhl > 0) valhl = 255;
    if (valhh > 0) valhh = 255;

    float val = coll*valll + cohl*valhl + colh*vallh + cohh*valhh;
    if (val<T) return 0;
    else return 255;
}


// special iterpolation version
// Grey values are ignored / interpreted as white.
// values outside images are interpreted as white either.
float interpolate_bilinear(bytearray &img, float x, float y) {
    byte valll, valhl, vallh, valhh;
    int xl = (int)x;
    int yl = (int)y;
    float u = x - xl;
    float v = y - yl;
    float coll, cohl, colh, cohh;
    coll = (1-u)*(1-v);
    cohl = u*(1-v);
    colh = (1-u)*v;
    cohh = u*v;

    if (IN(xl,yl,img)) valll = img(xl,yl);
    else valll = 255;
    if (IN(xl,yl+1,img)) vallh = img(xl,yl+1);
    else vallh = 255;
    if (IN(xl+1,yl,img)) valhl = img(xl+1,yl);
    else valhl = 255;
    if (IN(xl+1,yl+1,img)) valhh = img(xl+1,yl+1);
    else valhh = 255;

    if (valll > 0) valll = 255;
    if (vallh > 0) vallh = 255;
    if (valhl > 0) valhl = 255;
    if (valhh > 0) valhh = 255;

    return coll*valll + cohl*valhl + colh*vallh + cohh*valhh;
}

// scale box from source image to box in dest image
void scale_box_gray_from_gray(bytearray &dst, rectangle bDst,
                              bytearray &src,rectangle bSrc) {
    int w = bDst.width();
    int h = bDst.height();
    float u,v;
    float xSrc, ySrc;

    for (int i=0; i<=w; i++)
        for (int j=0; j<=h; j++) {
            u = (float)i/w;
            v = (float)j/h;

            xSrc = bSrc.x0 + u * (bSrc.x1-bSrc.x0);
            ySrc = bSrc.y0 + v * (bSrc.y1-bSrc.y0);

            if(IN(bDst.x0+i,bDst.y0+j,dst)) {
                int val = (int)interpolate_bilinear_from_gray(src,xSrc,ySrc);
                dst(bDst.x0+i,bDst.y0+j) =
                    val;
            }
        }
}

// scale box from source image to box in dest image
void scale_box_gray(bytearray &dst, rectangle bDst, 
                    bytearray &src, rectangle bSrc) {
    int w = bDst.width();
    int h = bDst.height();
    float u,v;
    float xSrc, ySrc;

    for (int i=0; i<=w; i++)
        for (int j=0; j<=h; j++) {
            u = (float)i/w;
            v = (float)j/h;

            xSrc = bSrc.x0 + u * (bSrc.x1-bSrc.x0);
            ySrc = bSrc.y0 + v * (bSrc.y1-bSrc.y0);

            if(IN(bDst.x0+i,bDst.y0+j,dst)) {
                int val = (int)interpolate_bilinear(src,xSrc,ySrc);
                dst(bDst.x0+i,bDst.y0+j) =
                    val;
            }
        }
}

// scale box from source image to box in dest image
void scale_box_bin_from_gray(bytearray &dst, rectangle bDst,
                             bytearray &src, rectangle bSrc,
                             int T) {
    int w = bDst.width();
    int h = bDst.height();
    float u,v;
    float xSrc, ySrc;

    for (int i=0; i<=w; i++)
        for (int j=0; j<=h; j++) {
            u = (float)i/w;
            v = (float)j/h;

            xSrc = bSrc.x0 + u * (bSrc.x1-bSrc.x0);
            ySrc = bSrc.y0 + v * (bSrc.y1-bSrc.y0);

            if(IN(bDst.x0+i,bDst.y0+j,dst)) {
                float val = (int)interpolate_bilinear_from_gray(src,xSrc,ySrc);
                dst(bDst.x0+i,bDst.y0+j) =
                    val<T? 0 : 255;
            }
        }
}

// scale box from source image to box in dest image
void scale_box_bin(bytearray &dst,rectangle bDst,
                   bytearray &src,rectangle bSrc,
                   byte T) {
    int w = bDst.width();
    int h = bDst.height();
    float u,v;
    float xSrc, ySrc;

    for (int i=0; i<=w; i++)
        for (int j=0; j<=h; j++) {
            u = (float)i/w;
            v = (float)j/h;

            xSrc = bSrc.x0 + u * (bSrc.x1-bSrc.x0);
            ySrc = bSrc.y0 + v * (bSrc.y1-bSrc.y0);

            dst(bDst.x0+i,bDst.y0+j) = (int)interpolate_bin(src,xSrc,ySrc,T);
        }
}

void normalize_image(floatarray &img) {
    float maximum = max(img);
    if(maximum!=0) {
        for(int i=0;i<img.length1d();i++) {
            img.at1d(i) = img.at1d(i)*255./maximum;
        }
    }
}

void normalize_image(bytearray &img) {
    float maximum = max(img);
    if(maximum!=0) {
        for(int i=0;i<img.length1d();i++) {
            img.at1d(i) = int(img.at1d(i)*255./maximum);
        }
    }
}

inline float force_to_range(float x,float low,float high) {
    float d = high-low;
    if(x<low) do{x+=d;} while(x<low);
    else if(x>=high) do{x-=d;} while(x>=high);
    return x;
}

bool color_neighbors(bytearray &img,rectangle b,point p,int color) {
    int x = p.x;
    int y = p.y;
    bool change=false;
    for (int i=-1;i<=1;i++)
        for (int j=-1;j<=1;j++)
            if ((i!=0||j!=0) && IN_BOX(x+i,y+j,b)
                && IN(x+i,y+j,img) && img(x+i,y+j)==255) {
                set(img,x+i,y+j,color);
                change=true;
            }
    return change;
}

bool is_boundary_pixel_wang(colib::bytearray &img, point p, int flag) {
    int x = p.x;
    int y = p.y;

    if (img(x,y)!=0) return false;

    byte vals[8];
    for (int i=0; i<8; i++)
        vals[i] = get(img,x+n_x[i],y+n_y[i])<255?0:255;
    // some of the neighbors may be labelled with 1, but in fact are 0!

    // first criterion: only ONE white-black-passage
    int bw_count = 0;
    for (int i=0; i<8; i++)
        if (vals[i]==255 && vals[(i+1)%8]==0) bw_count++;
    if (bw_count>1) return false;

    // second criterion: at least three black pixel neighbors
    int b_count = 0;
    for (int i=0; i<8; i++)
        if (vals[i]==0) b_count++;
    if (b_count<2 || b_count>6) return false;


    // according to wang: two possibilities.
    if (flag==1)
        if (vals[0]*vals[2]*vals[4]==0 && vals[2]*vals[4]*vals[6]==0 && vals[5]>0) return true;
    if (flag==2)
        if (vals[0]*vals[2]*vals[6]==0 && vals[0]*vals[4]*vals[6]==0 && vals[1]>0) return true;

    return false;

}

bool mark_boundary_pixels(colib::bytearray &img, rectangle b, int flag) {
    bool marked = false;
    for (int i=b.x0; i<=b.x1; i++)
        for (int j=b.y0; j<=b.y1; j++) {
            if (is_boundary_pixel_wang(img,point(i,j),flag)) {
                set(img,i,j,1);
                marked = true;
            }
        }
    return marked;
}

void delete_boundary_pixels(colib::bytearray &img, rectangle b) {
    for (int i=b.x0; i<=b.x1; i++)
        for (int j=b.y0; j<=b.y1; j++)
            if (get(img,i,j)==1) set(img,i,j,255);
}

void thinning_box(colib::bytearray &img, rectangle b) {

    bool change1,change2;
    do {
        change1 = change2 = false;

        change1 = mark_boundary_pixels(img,b,1);
        if (change1) delete_boundary_pixels(img,b);
        change2 = mark_boundary_pixels(img,b,2);
        if (change2) delete_boundary_pixels(img,b);

    } while(change1||change2);
}

int num_bin_neighbors(bytearray &img,int x,int y) {
    int n_count=0;
    for (int i=0; i<8; i++)
        if (get(img,x+n_x[i],y+n_y[i])!=255) n_count++;
    return n_count;
}

rectangle scale_feature_box(rectangle b_in, int w_dst, int h_dst) {
    // calc dst box
    int w = b_in.width();
    int h = b_in.height();
    rectangle dst_box;
    if (w>h) {
        float dst_height = h_dst * h/w;
        float m = 0.5*(h_dst-1);
        dst_box=rectangle(0,(int)(m-dst_height/2),w_dst-1,(int)(m+dst_height/2));
    }
    else {
        float dst_width = w_dst * (h>0?(float)w/h:0);
        float m = 0.5*(w_dst-1);
        // make box a bit wider for letters like 'i' and 'l'
        dst_box=rectangle((int)(m-dst_width/2-1),0,(int)(m+dst_width/2+1),h_dst-1);
    }
    return dst_box.intersection(rectangle(0,0,w_dst-1,h_dst-1));
}

float interpolate_bilinear_0(floatarray &img,float x,float y) {
    float valll, valhl, vallh, valhh;
    int xl = (int)x;
    int yl = (int)y;
    float u = x - xl;
    float v = y - yl;
    float coll, cohl, colh, cohh;
    coll = (1-u)*(1-v);
    cohl = u*(1-v);
    colh = (1-u)*v;
    cohh = u*v;

    if (IN(xl,yl,img)) valll = img(xl,yl);
    else valll = 0;
    if (IN(xl,yl+1,img)) vallh = img(xl,yl+1);
    else vallh = 0;
    if (IN(xl+1,yl,img)) valhl = img(xl+1,yl);
    else valhl = 0;
    if (IN(xl+1,yl+1,img)) valhh = img(xl+1,yl+1);
    else valhh = 0;

    return coll*valll + cohl*valhl + colh*vallh + cohh*valhh;
}

void scale_box_0(floatarray &dst, rectangle bDst,floatarray &src, rectangle bSrc) {
    int w = bDst.width();
    int h = bDst.height();

    float u,v;
    float xSrc, ySrc;

    for (int i=0; i<=w; i++) {
        for (int j=0; j<=h; j++) {
            u = (float)i/w;
            v = (float)j/h;

            xSrc = bSrc.x0 + u * (bSrc.x1-bSrc.x0);
            ySrc = bSrc.y0 + v * (bSrc.y1-bSrc.y0);

            dst(bDst.x0+i,bDst.y0+j) = (int)interpolate_bilinear_0(src,xSrc,ySrc);
        }
    }
}

rectangle whole_image(bytearray &img) {
    return rectangle(0,0,img.dim(0)-1,img.dim(1)-1);
}

bool skeletal_key_point(colib::bytearray &img, point p) {
    int n_neighbors=num_bin_neighbors(img,p.x,p.y);
    return (n_neighbors==1 || n_neighbors>2);
}

bool skeletal_end_point(colib::bytearray &img, point p) {
    int n_neighbors=num_bin_neighbors(img,p.x,p.y);
    return (n_neighbors<=1);
}

bool skeletal_junction_point(colib::bytearray &img, point p) {
    int n_neighbors=num_bin_neighbors(img,p.x,p.y);
    return (n_neighbors>2);
}

void mark_skeletal_points(colib::bytearray &img,colib::bytearray &img2) {
    fill(img2, 0);
    for (int i=0; i<img.dim(0); i++) {
        for (int j=0; j<img.dim(1); j++) {
            if (img(i,j)!=0) continue;
            if (skeletal_end_point(img, point(i,j))) img(i,j)=42;
            else if (skeletal_junction_point(img, point(i,j))) img(i,j)=66;
        }
    }

    for (int i=0; i<img.dim(0); i++) {
        for (int j=0; j<img.dim(1); j++) {
            if (img(i,j)==42) {
                img(i,j)=255;
                continue;
            }
            if (img(i,j)==66) {
                img2(i,j)=255;
            }
            img(i,j)=0;
        }
    }
}

void dilate_1(bytearray &img) {
    for (int i=0; i<img.dim(0); i++) {
        for (int j=0; j<img.dim(1); j++) {
            if (img(i,j)==255) {
                for (int k=0; k<8; k++)
                    if (get(img,i+n_x[k],j+n_y[k])!=255)
                        set(img,i+n_x[k],j+n_y[k], 128);
            }
        }
    }

    for (int i=0; i<img.dim(0); i++) {
        for (int j=0; j<img.dim(1); j++) {
            if (img(i,j)==128) img(i,j)=255;
        }
    }
}

void binarize_image(bytearray &dst,bytearray &img,int T) {
    for (int i=0;i<img.dim(0); i++)
        for (int j=0;j<img.dim(1); j++)
            dst(i,j)= img(i,j)<T ? 0 : 255;
}

void push_neighbors_255(bytearray &img,point p,narray<point> *s,int mode) {
    int i = p.x;
    int j = p.y;

    if(IN(i,j-1,img)) {
        if (img(i  ,j-1) == 255) {
            s->push(point(i  ,j-1));
        }
    }
    if (mode==8) {
        if (IN(i+1,j-1,img)) {
            if (img(i+1,j-1) == 255) {
                s->push(point(i+1,j-1));
            }
        }
    }

    if (IN(i+1,j  ,img)) {
        if (img(i+1,j  ) == 255) {
            s->push(point(i+1,j  ));
        }
    }

    if (mode==8) {
        if (IN(i+1,j+1,img)) {
            if (img(i+1,j+1) == 255) {
                s->push(point(i+1,j+1));
            }
        }
    }

    if (IN(i  ,j+1,img)) {
        if (img(i  ,j+1) == 255) {
            s->push(point(i  ,j+1));
        }
    }

    if (mode==8) {
        if (IN(i-1,j+1,img)) {
            if (img(i-1,j+1) == 255) {
                s->push(point(i-1,j+1));
            }
        }
    }

    if (IN(i-1,j  ,img)) {
        if (img(i-1,j  ) == 255) {
            s->push(point(i-1,j  ));
        }
    }

    if (mode==8) {
        if (IN(i-1,j-1,img)) {
            if (img(i-1,j-1) == 255) {
                s->push(point(i-1,j-1));
            }
        }
    }
}

void grow_white(bytearray &src,point seed){
    int MODE = 4;
    narray<point> pixels;
    pixels.clear();
    pixels.push(seed);

    while (pixels.length()) {

        point p = pixels.pop();
        if (src(p.x,p.y)!=255) continue;
        set(src,p.x,p.y,0);
        push_neighbors_255(src, p, &pixels, MODE);
    }
}

bool white_pixel_on_boundary(bytearray &img, point *p) {
    for (int i=0; i<img.dim(0); i++) {
        if (img(i,0)==255) {
            p->x = i;
            p->y = 0;
            return true;
        }
        if (img(i,img.dim(1)-1)==255) {
            p->x = i;
            p->y = img.dim(1)-1;
            return true;
        }
    }

    for (int j=0; j<img.dim(1); j++) {
        if (img(0,j)==255) {
            p->x = 0;
            p->y = j;
            return true;
        }
        if (img(img.dim(0)-1,j)==255) {
            p->x = img.dim(0)-1;
            p->y = j;
            return true;
        }
    }
    return false;
}

void binarize_inclusions(colib::bytearray &img) {
    // find some white pixel and grow from there.
    point white_pix;
    while(white_pixel_on_boundary(img, &white_pix)) {
        grow_white(img,white_pix);
    }
}

void preprocess(bytearray &image) {
    rectangle red_box = find_one_box(image,150);
    bytearray img_tmp;
    img_tmp.resize((int)round(STANDARD_Y*(float)red_box.width()/red_box.height()),STANDARD_Y);
    if(red_box.width()!=0&&red_box.height()!=0) {
        scale_box_gray_from_gray(img_tmp,whole_image(img_tmp),image,red_box);
        move(image,img_tmp);
    }
}

// _____________________________________________________________________________

void FeatureExtractor::setImage(bytearray &image) {
    copy(lineimage,image);        
}

void FeatureExtractor::setLineInfo(int basepoint_in,int xheight_in) {
    basepoint = basepoint_in;
    xheight = xheight_in;
}

void FeatureExtractor::getFeatures(floatarray &feature,
                                   rectangle r,
                                   FeatureType ftype) {
    bytearray subimage;
    crop(subimage,lineimage,r);
    if(ftype==IMAGE) {
        preprocess(subimage);
        calculate_image_feature(feature,subimage);
    }
    else if(ftype==GRAD) {
        preprocess(subimage);
        calculate_grad_feature(feature,subimage);
    }
    else if(ftype==BAYS) {
        preprocess(subimage);
        calculate_bays_feature(feature,subimage);
    }
    else if(ftype==SKEL) {
        preprocess(subimage);
        calculate_skel_feature(feature,subimage);
    }
    else if(ftype==SKELPTS) {
        preprocess(subimage);
        calculate_skelpts_feature(feature,subimage);
    }
    else if(ftype==INCL) {
        preprocess(subimage);
        calculate_incl_feature(feature,subimage);
    }
    else if(ftype==POS) {
        calculate_pos_feature(feature,subimage);
    }
    else if(ftype==RELSIZE) {
        calculate_relsize_feature(feature,subimage);
    }
    else {
        throw "feature type not implemented yet.";
    }
}

void FeatureExtractor::appendFeatures(floatarray &vector,rectangle r,
                                      FeatureType ftype) {
    floatarray feature;
    getFeatures(feature,r,ftype);
    for(int i=0;i<feature.length();i++) {
        vector.push(feature(i));
    }
}

void FeatureExtractor::appendFeaturesRescaled(floatarray &vector,int w,int h,
                                              rectangle r,
                                              FeatureType ftype) {
}

void FeatureExtractor::getFeatures(floatarray &feature, bytearray
                                   &input_image,FeatureType ftype) {
    bytearray subimage;
    copy(subimage,input_image);
    if(ftype==IMAGE) {
        preprocess(subimage);
        calculate_image_feature(feature,subimage);
    }
    else if(ftype==GRAD) {
        preprocess(subimage);
        calculate_grad_feature(feature,subimage);
    }
    else if(ftype==BAYS) {
        preprocess(subimage);
        calculate_bays_feature(feature,subimage);
    }
    else if(ftype==SKEL) {
        preprocess(subimage);
        calculate_skel_feature(feature,subimage);
    }
    else if(ftype==SKELPTS) {
        preprocess(subimage);
        calculate_skelpts_feature(feature,subimage);
    }
    else if(ftype==INCL) {
        preprocess(subimage);
        calculate_incl_feature(feature,subimage);
    }
    else if(ftype==POS) {
        calculate_pos_feature(feature,subimage);
    }
    else if(ftype==RELSIZE) {
        calculate_relsize_feature(feature,subimage);
    }
    else {
        throw "feature type not implemented yet.";
    }
}

void FeatureExtractor::appendFeatures(floatarray &vector,bytearray &subimage,
                                      FeatureType ftype) {
    floatarray feature;
    getFeatures(feature,subimage,ftype);
    for(int i=0;i<feature.length();i++) {
        vector.push(feature(i));
    }
}

void FeatureExtractor::calculate_image_feature(floatarray &image_feature,
                                               bytearray &input_image) {
    bytearray img;
    embed_img_with_white(img,input_image,3);
    gauss2d(img,2.5,2.5);
    rectangle red_box = find_one_box(img,253);
    rectangle out_box = scale_feature_box(red_box,DIM_X,DIM_Y);
    bytearray rescaled;
    rescaled.resize(DIM_X,DIM_Y);
    fill(rescaled,255);
    scale_box_gray_from_gray(rescaled,out_box,img,red_box);
    image_feature.resize(DIM_X*DIM_Y);

    int c = 0;
    for(int j=0;j<rescaled.dim(1);++j) {
        for(int i=0;i<rescaled.dim(0);++i) {
            image_feature(c++) = rescaled(i,j);
        }
    }
}

void FeatureExtractor::calculate_grad_feature(floatarray &grad_feature,
                                              bytearray &input_image) {
    bytearray image;
    embed_img_with_white(image,input_image,3);
    gauss2d(image,1.5,1.5);
    rectangle red_box = find_one_box(image,253);
    bytearray tmp;
    tmp.resize(red_box.x1-red_box.x0+1,red_box.y1-red_box.y0+1);
    rectangle tmp_box = rectangle(0,0,tmp.dim(0)-1,tmp.dim(1)-1);
    scale_box_gray_from_gray(tmp,tmp_box,image,red_box);
    move(image,tmp);

    objlist<floatarray> gradients;
    floatarray grad0;
    floatarray grad1;
    floatarray grad2;
    floatarray grad3;
    gradients.clear();
    move(gradients.push(),grad0);
    move(gradients.push(),grad1);
    move(gradients.push(),grad2);
    move(gradients.push(),grad3);
    for(int k=0;k<gradients.length();++k) {
        gradients[k].resize(image.dim(0),image.dim(1));
    }

    float angle_range = M_PI;
    float angle_range2 = angle_range/2.0;
    float owidth = 0.7*(angle_range/gradients.length());
    float ocoef = 1.0f/(2.0f*owidth*owidth);

    for(int i=0;i<image.dim(0);++i) {
        for(int j=0;j<image.dim(1);++j) {
            float dx = get(image,i,j)-get(image,i-1,j);
            float dy = get(image,i,j)-get(image,i,j-1);
            float angle = (dx!=0.0||dy!=0.0)?atan2(dy,dx):0.0;
            float gradm = hypot(dy,dx);///MAX_GRADM;

            for(int k=0;k<gradients.length();++k) {
                float ocenter = (angle_range*k)/gradients.length();
                float da = force_to_range(angle-ocenter,-angle_range2,angle_range2);
                (gradients[k])(i,j) = (byte)(gradm*exp(-da*da*ocoef));
            }
        }
    }

    floatarray rescaled;
    rectangle dst_box = scale_feature_box(tmp_box,DIM_X,DIM_Y);
    for(int k=0;k<gradients.length();++k) {
        gauss2d(gradients[k],2,2);
        rescaled.resize(DIM_X,DIM_Y);
        fill(rescaled,0);
        scale_box_0(rescaled,dst_box,gradients[k],tmp_box);
        //rescale(rescaled,gradients[k],DIM_X,DIM_Y);
        normalize_image(rescaled);
        move(gradients[k],rescaled);
    }
    grad_feature.resize(gradients.length()*DIM_X*DIM_Y);
    int c = 0;
    for(int k=0;k<gradients.length();++k) {
        for(int i=0;i<gradients[k].length1d();i++) {
            grad_feature(c) = gradients[k].at1d(i);
            c++;
        }
    }

}

void FeatureExtractor::calculate_bays_feature(floatarray &bays_feature,
                                              bytearray &input_image) {
    bytearray image;
    rectangle red_box = find_one_box(input_image,254);
    image.resize(red_box.width(),red_box.height());
    rectangle image_box = rectangle(0,0,image.dim(0)-1,image.dim(1)-1);
    scale_box_bin_from_gray(image,image_box,input_image,red_box,170);

    floatarray bay0;
    bay0.resize(image.dim(0),image.dim(1));
    fill(bay0, 0); // from the left
    floatarray bay1; // from the right
    bay1.resize(image.dim(0),image.dim(1));
    fill(bay1, 0);
    floatarray bay2; // from the bottom
    bay2.resize(image.dim(0),image.dim(1));
    fill(bay2, 0);
    floatarray bay3; // from the top
    bay3.resize(image.dim(0),image.dim(1));
    fill(bay3, 0);

    for(int j=0;j<image.dim(1);++j) {
        for(int i=0;i< image.dim(0) && image(i,j)==255;++i) {
            bay0(i,j) = 255;
        }
        for(int i=image.dim(0)-1;i>=0 && image(i,j)==255;--i) {
            bay1(i,j) = 255;
        }
    }

    for (int i=0;i<image.dim(0);++i) {
        for(int j=0;j<image.dim(1) && image(i,j)==255;++j)
            bay2(i,j) = 255;
        for(int j=image.dim(1)-1;j>=0 && image(i,j)==255;--j)
            bay3(i,j) = 255;
    }

    gauss2d(bay0,1,1);
    gauss2d(bay1,1,1);
    gauss2d(bay2,1,1);
    gauss2d(bay3,1,1);

    rectangle dst_box = rectangle(0,0,DIM_X-1,DIM_Y-1);
    floatarray bay0rescaled;
    bay0rescaled.resize(DIM_X,DIM_Y);
    fill(bay0rescaled,0);
    scale_box_0(bay0rescaled,dst_box,bay0,image_box);
    //rescale(bay0rescaled,bay0,DIM_X,DIM_Y);
    floatarray bay1rescaled;
    bay1rescaled.resize(DIM_X,DIM_Y);
    fill(bay1rescaled,0);
    scale_box_0(bay1rescaled,dst_box,bay1,image_box);
    //rescale(bay1rescaled,bay1,DIM_X,DIM_Y);
    floatarray bay2rescaled;
    bay2rescaled.resize(DIM_X,DIM_Y);
    fill(bay2rescaled,0);
    scale_box_0(bay2rescaled,dst_box,bay2,image_box);
    //rescale(bay2rescaled,bay2,DIM_X,DIM_Y);
    floatarray bay3rescaled;
    bay3rescaled.resize(DIM_X,DIM_Y);
    fill(bay3rescaled,0);
    scale_box_0(bay3rescaled,dst_box,bay3,image_box);
    //rescale(bay3rescaled,bay3,DIM_X,DIM_Y);

    bays_feature.resize(4*DIM_X*DIM_Y);
    int c = 0;
    for(int i=0;i<DIM_X*DIM_Y;i++) {
        bays_feature(c) = bay0rescaled.at1d(i);
        c++;
    }
    for(int i=0;i<DIM_X*DIM_Y;i++) {
        bays_feature(c) = bay1rescaled.at1d(i);
        c++;
    }
    for(int i=0;i<DIM_X*DIM_Y;i++) {
        bays_feature(c) = bay2rescaled.at1d(i);
        c++;
    }
    for(int i=0;i<DIM_X*DIM_Y;i++) {
        bays_feature(c) = bay3rescaled.at1d(i);
        c++;
    }
}

void FeatureExtractor::calculate_skel_feature(floatarray &skel_feature,
                                              bytearray &input_image) {
    bytearray image;
    image.resize(DIM_X,DIM_Y);
    rectangle red_box = find_one_box(input_image);
    rectangle scaled_box = rectangle(0,0,DIM_X-1,DIM_Y-1);
    scale_box_bin(image,scaled_box,input_image,red_box,200);
    thinning_box(image,scaled_box);

    int DIST_STEP = 10;
    bool change;
    byte dist=0;
    do {
        change = false;
        for(int i=scaled_box.x0;i<=scaled_box.x1;i++) {
            for(int j=scaled_box.y0;j<=scaled_box.y1;j++) {
                if(get(image,i,j)==dist) {
                    if(color_neighbors(image,scaled_box,point(i,j),dist+DIST_STEP))
                        change=true;
                }
            }
        }
        dist+=DIST_STEP;
    } while(change);

    int c = 0;
    skel_feature.resize(DIM_X*DIM_Y);
    for(int j=0;j<image.dim(1);j++) {
        for(int i=0;i<image.dim(0);i++) {
            skel_feature(c) = image(i,j);
            c++;
        }
    }
}

void FeatureExtractor::calculate_skelpts_feature(floatarray &skelpts_feature,
                                                 bytearray &input_image) {
    bytearray bin_image;
    makelike(bin_image,input_image);
    binarize_image(bin_image,input_image,128);

    bytearray img;
    embed_img_with_white(img,bin_image,5);

    // fill gaps in character strokes. what does this do to usual characters?
    bytearray img2;
    img2.resize(img.dim(0),img.dim(1));

    invert(img);
    thin(img);
    invert(img);

    mark_skeletal_points(img,img2); // img is for endpoints, img2 for T junctions

    dilate_1(img);
    dilate_1(img);
    gauss2d(img,7,7);
    dilate_1(img2);
    dilate_1(img2);
    gauss2d(img2,7,7);

    // scaling
    colib::bytearray out;
    out.resize(DIM_X,DIM_Y);
    fill(out, 0);

    rectangle dst_box = scale_feature_box(whole_image(img), DIM_X,DIM_Y);
    scale_box_gray_from_gray(out,dst_box,img,whole_image(img));

    bytearray out2;
    out2.resize(DIM_X,DIM_Y);
    fill(out2, 0);
    scale_box_gray_from_gray(out2,dst_box,img2,whole_image(img));
    normalize_image(out);
    normalize_image(out2);

    int c = 0;
    skelpts_feature.resize(2*DIM_X*DIM_Y);
    for(int j=0;j<out.dim(1);j++) {
        for(int i=0;i<out.dim(0);i++) {
            skelpts_feature(c) = out(i,j);
            c++;
        }
    }
    for(int j=0;j<out2.dim(1);j++) {
        for(int i=0;i<out2.dim(0);i++) {
            skelpts_feature(c) = out2(i,j);
            c++;
        }
    }
}

void FeatureExtractor::calculate_incl_feature(floatarray &incl_feature,
                                              bytearray &input_image) {

    bytearray tmp;
    makelike(tmp,input_image);
    binarize_image(tmp,input_image,128);


    binarize_inclusions(tmp);
    gauss2d(tmp,1,1);

    // scale inclusions image down.
    bytearray out;
    out.resize(DIM_X,DIM_Y);
    fill(out,0);
    rectangle dst_box = scale_feature_box(whole_image(tmp),DIM_X,DIM_Y);
    scale_box_gray(out,dst_box,tmp,whole_image(tmp));

    gauss2d(out,1,1);

    incl_feature.resize(DIM_X*DIM_Y);
    int c = 0;
    for(int j=0;j<out.dim(1);++j) {
        for(int i=0;i<out.dim(0);++i) {
            incl_feature(c++) = out(i,j);
        }
    }
}

void FeatureExtractor::calculate_pos_feature(floatarray &position_feature,
                                             bytearray &input_image) {
    position_feature.resize(DIM_X);

    fill(position_feature,0);
    int x,y;

    // go through input_image linewise from bottom and find lowest part of the char
    bool leave = false;
    for(y=0;(y < input_image.dim(1))&&!leave;++y) {
        for (x=0; x < input_image.dim(0); ++x) {
            if ( input_image(x,y) == 0) {
                // found black pixel, make sure it's not alone
                int neighbors = 0;
                // check one to the right
                if (x < input_image.dim(0) - 1) {
                    if ( input_image(x+1,y) == 0) ++neighbors;
                }
                if (x > 0 && y < input_image.dim(1) - 1) {
                    // check one above
                    if ( input_image(x,y+1) == 0) ++neighbors;
                    // check to the left of one above
                    if ( input_image(x-1,y+1) == 0) ++neighbors;
                    // check to the right of one above
                    if ((x < input_image.dim(0) - 1) && ( input_image(x+1,y+1)) == 0) ++neighbors;
                }
                // leave if we found at least one neighbor
                if (neighbors > 0) {
                    leave = true;
                    break;
                }
            }
        }
    }
    // distance from the baspoint of the text line
    float position = (float) (y - basepoint);
    // relative position in units of xheight
    float relativePosition = 0.f;
    // we assume a possible range of 'positions' between
    // 0.5 * xheight below baseline and 2.0 * xheight above baseline
    // that's why we must add 0.5 to position before we divide it by the
    // entire range of values (0.5 + 2.0 = 2.5)
    relativePosition = ((position + 0.5 * (float) xheight) / (2.5 * (float) xheight));

    // unary coding
    for (int j=0; j < position_feature.dim(0); ++j) {
        if (((float)j / (float)(position_feature.dim(0))) < relativePosition) {
            position_feature(j) = 255;
        }
    }
    gauss1d(position_feature, 1.5);
}

void FeatureExtractor::calculate_relsize_feature(floatarray &relsize_feature,
                                                 bytearray &input_image) {
    rectangle box = find_one_box(input_image);
    float height = box.height();
    float rel_size = height/xheight;
    
    // unary coding
    relsize_feature.resize(DIM_X);
    for (int j=0;j<relsize_feature.dim(0);++j) {
        if(((float)j/(relsize_feature.dim(0)-1))>(rel_size/MAX_REL_SIZE)) {
            relsize_feature(j)=0;
        }
        else relsize_feature(j)=255;
    }
    gauss1d(relsize_feature,1.5);
}

namespace ocropus {
    FeatureExtractor *make_FeatureExtractor() {
        return new FeatureExtractor();
    }
};
