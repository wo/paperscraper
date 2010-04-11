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
// File: ocr-ctextline-rast.h
// Purpose: Header file declaring data structures for constrained textline
//          extraction using RAST
// Responsible: Faisal Shafait (faisal.shafait@dfki.de)
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#ifndef h_ocrctextlinerast__
#define h_ocrctextlinerast__

#include "colib.h"
#include "heap.h"
#include "iarith.h"

#include "ocr-char-stats.h"

namespace ocropus {



    /////////////////////////////////////////////////////////////////////
    ///
    /// \struct TextLineParam
    /// Purpose: Textline parameters
    ///
    //////////////////////////////////////////////////////////////////////
    
    struct TextLineParam {
        float c,m,d; // c is y-intercept, m is slope, d is the line of descenders
        void print(FILE *stream=stdout){
            fprintf(stream,"%.3f %f %.2f\n",c,m,d);
        }
    };

    /////////////////////////////////////////////////////////////////////
    ///
    /// \struct CTextlineRASTBasic
    /// Purpose: Basic implementation of the constrained textline finding
    ///          algorithm using RAST. Returns parameters of text-lines in 
    ///          descending order of quality.
    ///
    //////////////////////////////////////////////////////////////////////

    const int nparams = 3;
    struct CTextlineRASTBasic {
        CTextlineRASTBasic();
        virtual ~CTextlineRASTBasic(){
        }
        int    generation;
        bool   lsq;
        double epsilon;
        int    maxsplits;
        double delta;
        double adelta;

        float  min_length;
        int    min_gap;
        double min_q;
        int    min_count;
        int    max_results;
        bool   use_whitespace;

        typedef vecni<nparams> Parameters;
        double splitscale[nparams];
        Parameters all_params;
        Parameters empty_parameters;
        
        vec2i normalized(vec2i v) {
            interval a = atan2(v.y,v.x);
            return vec2i(cos(a),sin(a));
        }

        inline interval influence(bool lsq,interval d,double epsilon) {
            if(lsq) return sqinfluence(d,epsilon);
            else return rinfluence(d,epsilon);
        }
        
        typedef colib::narray<int> Matches;
        colib::rectarray cboxes;
        colib::rectarray wboxes;
        colib::narray<bool> used;
        
        bool final(interval q,const Parameters &p) {
            return p[0].width()<delta &&
                p[1].width()<adelta &&
                p[2].width()<delta;
        }
        
        struct TLStateBasic {
            short       generation;
            short       depth;
            short       rank;
            signed char splits;
            bool        splittable;
            interval    quality;
            float       priority;
            Parameters  params;
            Matches     matches;
            
            TLStateBasic();
            void set(CTextlineRASTBasic &line,int depth,Parameters &params,
                     Matches &candidates,int splits);
            void reeval(CTextlineRASTBasic &line);
            void update(CTextlineRASTBasic &line, Matches &candidates);
            TextLineParam returnLineParam();
        };
        
        typedef counted<TLStateBasic> CState;
        heap<CState> queue;
        colib::narray<CState> results;
        colib::autodel<CharStats> linestats;
        Matches all_matches;
        
        void setDefaultParameters();
        void set_max_slope(double max_slope);
        void set_max_yintercept(double ymin, double ymax);
        void prepare();
        void make_substates(colib::narray<CState> &substates,CState &state);
        int  wbox_intersection(CState &top);
        void search();
        virtual void push_result(CState &result);
        virtual void extract(colib::narray<TextLineParam> &textlines, 
                             colib::autodel<CharStats> &charstats);
        virtual void extract(colib::narray<TextLineParam> &textlines, 
                             colib::rectarray &columns,
                             colib::autodel<CharStats>    &charstats);
    };
    CTextlineRASTBasic *make_CTextlineRASTBasic();
    
    /////////////////////////////////////////////////////////////////////
    ///
    /// \struct TextLine
    /// Purpose: Textline bounding box and it attributes
    ///
    //////////////////////////////////////////////////////////////////////
    
    struct TextLine : TextLineParam{
        TextLine(){
        }
        TextLine(TextLineParam &tl){
            c = tl.c;
            m = tl.m;
            d = tl.d;
        }
        int   xheight;
        colib::rectangle  bbox;
        void print(FILE *stream=stdout){
            fprintf(stream,"%d %d %d %d ",bbox.x0,bbox.y0,bbox.x1,bbox.y1);
            fprintf(stream,"%.3f %f %.2f %d\n",c,m,d,xheight);
        }
    };

    /////////////////////////////////////////////////////////////////////
    ///
    /// \struct CTextlineRAST
    /// Purpose: Constrained Textline finding using RAST
    ///
    //////////////////////////////////////////////////////////////////////
    struct CTextlineRAST : CTextlineRASTBasic{
        
        CTextlineRAST();
        ~CTextlineRAST(){ }
        // fraction of area covered by line bounding box
        // so that char_box is included in line_box
        float  minoverlap;

        // rejection threshold for the height of a box = tr*xheight
        float  min_box_height; 

        // average distance between words
        int    word_gap; 

        int    min_height;
        int    assign_boxes;
        bool   aggressive;
        int    extend;
        int    pagewidth;
        int    pageheight;

        colib::rectarray cboxes_all;
        colib::narray<bool> used_all;
        colib::narray<TextLine> result_lines;

        void setDefaultParameters();
        void push_result(CState &result);
        void extract(colib::narray<TextLine> &textlines, 
                     colib::autodel<CharStats> &charstats);
        void extract(colib::narray<TextLine> &textlines, 
                     colib::rectarray &columns,
                     colib::autodel<CharStats>    &charstats);
    };
    CTextlineRAST *make_CTextlineRAST();

}

#endif
