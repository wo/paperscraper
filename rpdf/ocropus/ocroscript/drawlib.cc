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

#include "SDL/SDL.h"
#include "colib.h"
#include "drawlib.h"

namespace ocropus {
    namespace {
        int min(int x,int y) { return x<y?x:y; }
        int max(int x,int y) { return x>y?x:y; }
    }

    static int initialized = 0;

    static void maybe_initialize() {
        if(initialized) return;
        initialized = 1;
        SDL_Init(SDL_INIT_VIDEO);
    }

    struct Pixels {
        SDL_Surface *screen;
        unsigned int *pixels;
        int pitch;
        unsigned int trash;
        int w,h;
        Pixels(SDL_Surface *screen):screen(screen) {
            SDL_LockSurface(screen);
            pixels = (unsigned int *)screen->pixels;
            pitch = screen->pitch/4;
            w = screen->w;
            h = screen->h;
        }
        unsigned int &operator()(int x,int y) {
            if(unsigned(x)>=unsigned(w)||unsigned(y)>=unsigned(h))
                return trash;
            return pixels[y*pitch+x];
        }
        ~Pixels() {
            SDL_UnlockSurface(screen);
        }
    };

    struct DebugDraw : IDebugDraw {
        int w,h;
        SDL_Surface *screen;
        DebugDraw() {
            screen = 0;
        }
        ~DebugDraw() {
        }
        void init(int w,int h) {
            maybe_initialize();
            this->w = w;
            this->h = h;
            screen = SDL_SetVideoMode(w,h,32,SDL_SWSURFACE);
        }
        void draw(bytearray &image,int x,int y) {
            if(!screen) throw "screen not initialized";
            Pixels a(screen);
            for(int i=0;i<image.dim(0);i++) for(int j=0;j<image.dim(1);j++) {
                int v = image(i,image.dim(1)-j-1);
                a(i+x,j+y) = ((v<<16)|(v<<8)|v);
            }
            SDL_UpdateRect(screen,max(x,0),max(y,0),min(x+image.dim(0),w),min(y+image.dim(1),h));
        }
        void draw(intarray &image,int x,int y) {
            if(!screen) throw "screen not initialized";
            Pixels a(screen);
            for(int i=0;i<image.dim(0);i++) for(int j=0;j<image.dim(1);j++) {
                int v = image(i,image.dim(1)-j-1);
                a(i+x,j+y) = v;
            }
            SDL_UpdateRect(screen,max(x,0),max(y,0),min(x+image.dim(0),w),min(y+image.dim(1),h));
        }
    };

    IDebugDraw *make_DebugDraw() {
        return new DebugDraw();
    }
}
