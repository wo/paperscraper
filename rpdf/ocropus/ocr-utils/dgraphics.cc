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

#include <SDL/SDL.h>
#include <SDL/SDL_gfxPrimitives.h>
#include <SDL/SDL_image.h>
#include <SDL/SDL_imageFilter.h>
#include <SDL/SDL_rotozoom.h>

#include <stdlib.h>
#include "colib.h"
#include "imglib.h"
#include "ocr-utils.h"
#include "dgraphics.h"

using namespace imglib;
using namespace colib;

namespace ocropus {
#if 0
    static SDL_Rect rect(int x,int y,int w,int h) { 
        SDL_Rect r; r.x = x; r.y = y; r.w = w; r.h = h; 
        return r; 
    }
    static SDL_Color color(int r,int g,int b) { 
        SDL_Color c; c.r = r; c.g = g; c.b = b; 
        c.unused = 0; // to remove compiler warning
        return c; 
    }
#endif
    static SDL_Rect rect(SDL_Surface *s) { 
        SDL_Rect r; r.x = 0; r.y = 0; r.w = s->w; r.h = s->h; 
        return r; 
    }
    static void SDL_UpdateRect(SDL_Surface *screen, SDL_Rect r) { 
        SDL_UpdateRect(screen,r.x,r.y,r.w,r.h); 
    }
#if 0
    static void Update(SDL_Surface *screen) { 
        SDL_UpdateRect(screen,0,0,screen->w,screen->h); 
    }
#endif

    static void ArrayBlit(SDL_Surface *dst,SDL_Rect *r,bytearray &data,double angle,double zoom,int smooth) {
        SDL_Surface *input = SDL_CreateRGBSurfaceFrom(&data.at1d(0),data.dim(1),data.dim(0),
                8,data.dim(1),0xff,0xff,0xff,0x00);
        SDL_SetAlpha(input,SDL_SRCALPHA,SDL_ALPHA_OPAQUE);
        SDL_Surface *output = rotozoomSurface(input,angle,zoom,smooth);
        SDL_SetAlpha(output,SDL_SRCALPHA,SDL_ALPHA_OPAQUE);
        SDL_FreeSurface(input);
        SDL_Rect sr; sr.x = 0; sr.y = 0; sr.w = output->w; sr.h = output->h;
        SDL_BlitSurface(output,&sr,dst,r);
        SDL_FreeSurface(output);
    }

    /*static void ArrayBlit(SDL_Surface *dst,SDL_Rect *r,intarray &data,double angle,double zoom,int smooth) {
        SDL_Surface *input = SDL_CreateRGBSurfaceFrom(&data.at1d(0),data.dim(1),data.dim(0),
                32,data.dim(1)*4,0xff0000,0xff00,0xff,0x00);
        SDL_SetAlpha(input,SDL_SRCALPHA,SDL_ALPHA_OPAQUE);
        SDL_Surface *output = rotozoomSurface(input,angle,zoom,smooth);
        SDL_SetAlpha(output,SDL_SRCALPHA,SDL_ALPHA_OPAQUE);
        SDL_FreeSurface(input);
        SDL_Rect sr; sr.x = 0; sr.y = 0; sr.w = output->w; sr.h = output->h;
        SDL_BlitSurface(output,&sr,dst,r);
        SDL_FreeSurface(output);
    }*/

    static void ParseSpec(double &x0,double &y0,double &x1,double &y1,const char *spec) {
        while(*spec) {
            switch(*spec) {
                case 'a': 
                    x1 = (x0+x1)/2;
                    y1 = (y0+y1)/2;
                    break;
                case 'b': 
                    x0 = (x0+x1)/2;
                    y1 = (y0+y1)/2;
                    break;
                case 'c': 
                    x1 = (x0+x1)/2;
                    y0 = (y0+y1)/2;
                    break;
                case 'd': 
                    x0 = (x0+x1)/2;
                    y0 = (y0+y1)/2;
                    break;
                case 'x': 
                    x1 = (x0+x1)/2;
                    break;
                case 'X': 
                    x0 = (x0+x1)/2;
                    break;
                case 'y': 
                    y1 = (y0+y1)/2;
                    break;
                case 'Y': 
                    y0 = (y0+y1)/2;
                    break;
            }
            spec++;
        }
    }

    static SDL_Surface *screen;
    
    void dinit(int w,int h) {
        SDL_Init(SDL_INIT_EVERYTHING);
        screen = SDL_SetVideoMode(w,h,32,SDL_SWSURFACE);
    }


    template <class T>
    void dshow(narray<T> &data,const char *spec,double angle,int smooth,int rgb) {
        if(!screen) return;
        bytearray temp;
        copy(temp,data);
        double x0=0,y0=0,x1=1,y1=1;
        ParseSpec(x0,y0,x1,y1,spec);
        SDL_Rect out = rect(screen);
        out.x = int(out.w * x0);
        out.y = int(out.h * y0);
        out.w = int(out.w * (x1-x0));
        out.h = int(out.h * (y1-y0));
        double xscale = out.w * 1.0 / temp.dim(0);
        double yscale = out.h * 1.0 / temp.dim(1);
        double scale = xscale<yscale?xscale:yscale;
        rgb = SDL_MapRGB(screen->format,((rgb&0xff0000)>>16),((rgb&0xff00)>>8),(rgb&0xff));
        SDL_FillRect(screen,&out,rgb);
        SDL_UpdateRect(screen,out.x,out.y,out.w,out.h);
        ArrayBlit(screen,&out,temp,angle,scale,smooth);
        SDL_UpdateRect(screen,out.x,out.y,out.w,out.h);
    }

    template void dshow(narray<unsigned char> &data,const char *spec,double angle,int smooth,int rgb);
    template void dshow(narray<int> &data,const char *spec,double angle,int smooth,int rgb);
    template void dshow(narray<float> &data,const char *spec,double angle,int smooth,int rgb);
/*    void dshow(narray<float> &data,const char *spec,double angle,int smooth,int rgb) {
     bytearray temp;
	copy(temp,data);
	dshow(temp,spec,angle,smooth,rgb);
    }*/

    template <class T>
    void dshown(narray<T> &data,const char *spec,double angle, int smooth, int rgb) {
        if(!screen) return;
	narray<T> temp;
	copy(temp,data);
	expand_range(temp,0,255);
	bytearray btemp;
	copy(btemp,temp);
	dshow(btemp,spec,angle,smooth,rgb);
    }
    template void dshown(narray<unsigned char> &data,const char *spec,double angle,int smooth,int rgb);
    template void dshown(narray<int> &data,const char *spec,double angle,int smooth,int rgb);
    template void dshown(narray<float> &data,const char *spec,double angle,int smooth,int rgb);

    void dshowr(intarray &data,const char *spec,double angle,int smooth,int rgb) {
        if(!screen) return;
        intarray temp;
        copy(temp,data);
        replace_values(temp,0xffffff,0);
        simple_recolor(temp);
        dshow(temp,spec,angle,smooth,rgb);
    }

    void dclear(int rgb) {
        if(!screen) return;
        SDL_Rect r = rect(screen);
        rgb = SDL_MapRGB(screen->format,((rgb&0xff0000)>>16),((rgb&0xff00)>>8),(rgb&0xff));
        SDL_FillRect(screen,&r,rgb);
        SDL_UpdateRect(screen,r.x,r.y,r.w,r.h);
    }

    void dwait() {
        if(!screen) return;
        SDL_Event event;
        while(SDL_WaitEvent(&event)) {
            if(event.type==SDL_KEYDOWN) break;
            if(event.type==SDL_MOUSEBUTTONDOWN) break;
            if(event.type==SDL_QUIT) break;
        }
    }
}
