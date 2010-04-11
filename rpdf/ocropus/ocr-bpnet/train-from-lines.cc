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
// Project:  ocr-bpnet - neural network classifier
// File: train-from-lines.cc
// Purpose: neural network classifier
// Responsible: Hagen Kaprykowsky (kapry@iupr.net)
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "imglib.h"
#include "colib.h"
#include "imgio.h"
#include "ocr-utils.h"
#include "narray-io.h"
#include "feature-extractor.h"
#include "classmap.h"
#include "bpnet.h"
#include "line-info.h"

using namespace ocropus;
using namespace imgio;
using namespace imglib;
using namespace colib;

param_int nhidden("nhidden",100,"Number of hidden units");
param_float learningrate("learningrate",0.05,"Learning rate");
param_float testportion("testportion",0.1,"Test portion (range: 0.0-1.0)");
param_int epochs("epochs",20,"Number of training epochs");
param_bool normalize("normalize",true,"Normalization");
param_bool shuffle("shuffle",true,"Shuffle");
param_bool debug("debug",false,"Debug");

/// Extract subimages of a color coded segmenation
static void extract_subimages(objlist<bytearray> &subimages,narray<rectangle> &bboxes,intarray &segmentation) {
    subimages.clear();
    bounding_boxes(bboxes,segmentation);
    for(int i=1;i<bboxes.length();i++) {
        intarray segment;
        rectangle &b = bboxes[i];
        extract_subimage(segment,segmentation,b.x0,b.y0,b.x1,b.y1);
        bytearray subimage;
        extract_segment(subimage,segment,i);
        copy(subimages.push(),subimage);
    }
}

int main(int argc,char **argv){

    try {
        if(argc!=3) {
            fprintf(stderr, "usage: ... file-list bpnet-file");
            exit(1);
        }

        autodel<FeatureExtractor> extractor(make_FeatureExtractor());
        autodel<Classifier> classifier(make_BpnetClassifier());
        classifier->start_training();

        classifier->param("nhidden",nhidden);
        classifier->param("epochs",epochs);
        classifier->param("learningrate",learningrate);
        classifier->param("testportion",testportion);
        classifier->param("normalize",normalize);
        classifier->param("shuffle",shuffle);

        ClassMap map;
        int ninput = -1;

        char trans[1000];
        intarray segmentation;
        objlist<bytearray> subimages;
        narray<rectangle> bboxes;
        int count=1;
        stdio file_list_fp = stdio(argv[1],"r");
        while(1) {
            char path[1000];
            if(fscanf(file_list_fp,"%s", path) != 1)
                break;
            printf("%s\n", path);
        
            char segmentation_file[1000];
            char transcript_file[1000];
            sprintf(segmentation_file,"%s.png",path);
            sprintf(transcript_file,"%s.txt",path);

            // extract subimages
            read_png_rgb(segmentation,stdio(segmentation_file,"rb"));
            replace_values(segmentation, 0xFFFFFF, 0);
            extract_subimages(subimages,bboxes,segmentation);
            float intercept;
            float slope;
            float xheight;
            float descender_sink;
            float ascender_rise;
            float baseline;
            float descender;
            float ascender;
            if(!get_extended_line_info(intercept,slope,xheight,
                                       descender_sink,ascender_rise,
                                       segmentation)) {
                intercept = 0;
                slope = 0;
                xheight = 0;
                descender_sink = 0;
                ascender_rise = 0;
                baseline = 0;
                descender = 0;
                ascender = 0;
            }

            xheight = estimate_xheight(segmentation,slope);

            // read transcript
            fgets(trans,256,stdio(transcript_file,"r"));
            nustring transcript(trans);

            if(debug) {
                for(int i=0;i<transcript.length();i++) {
                    putchar(transcript[i].ord());
                }
                printf("\nnumber of subimages: %d number of characters: "
                       "%d\n",subimages.length(),transcript.length()); 
            }
            if(subimages.length()!=transcript.length()) {
                continue;
            }

            // add data to classifier
            for(int i=0;i<subimages.length();i++) {
                floatarray features;
                baseline = intercept+bboxes[i].x0 *slope;
                ascender = baseline+xheight+descender_sink;
                descender = baseline-descender_sink;
                extractor->setLineInfo(int(baseline+0.5),int(xheight+0.5));
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::BAYS);
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::GRAD);
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::INCL);
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::IMAGE);
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::SKEL);
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::SKELPTS);
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::RELSIZE);
                extractor->appendFeatures(features,subimages[i],FeatureExtractor::POS);
                //extractor->extract(features,subimages[i],int(baseline+0.5),
                //                   int(xheight+0.5),
                //                   int(descender+0.5),
                //                   int(ascender+0.5));
                CHECK_CONDITION(ninput==-1||ninput==features.length());
                if(ninput==-1) {
                    ninput = features.length();
                }
                int cls = map.get_class(transcript[i].ord());
                classifier->add(features,cls);
                if(debug) {
                    char file_name[50];
                    sprintf(file_name,"subimage_%06d.png",count);
                    write_png(stdio(file_name,"w"),subimages[i]);
                }
                count++;
            }
        }

        classifier->param("ninput",ninput);
        classifier->param("noutput", map.length());
        classifier->start_classifying();
        stdio bpnet_fp = stdio(argv[2],"wa");
        map.save(bpnet_fp);
        classifier->save(bpnet_fp);
    }
    catch(const char *oops) {
        fprintf(stderr,"oops: %s\n",oops);
    }
    return 0;
}
