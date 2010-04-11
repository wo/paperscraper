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
#include "imgio.h"
#include "imglib.h"
#include "ocrcomponents.h"
#include "ocr-segmentations.h"
#include "ocr-utils.h"

using namespace ocropus;
using namespace imgio;
using namespace imglib;
using namespace colib;

#define DIM_X 10
#define DIM_Y 10

void feat2image(bytearray &image,floatarray &feature) {
    int c=0;
    int DIM_X_NFEAT = feature.length()/DIM_Y;
    image.resize(DIM_X_NFEAT,DIM_Y);
    for(int i=0;i<DIM_X_NFEAT;i++) {
        for(int j=0;j<DIM_Y;j++) {
            image(i,j) = byte(feature(c));
            //printf("feat: %f img: %d\n",feature(c),image(i,j));
            c++;
        }
    }
}

int main(int argc,char **argv){
    try {

        FeatureExtractor::FeatureType featuretype;
        featuretype = FeatureExtractor::GRAD;
        bool all = false;
        if(!strcasecmp(argv[3],"IMAGE")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::IMAGE;
        }
        else if(!strcasecmp(argv[3],"GRAD")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::GRAD;
        }
        else if(!strcasecmp(argv[3],"BAYS")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::BAYS;
        }
        else if(!strcasecmp(argv[3],"SKEL")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::SKEL;
        }
        else if(!strcasecmp(argv[3],"SKELPTS")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::SKELPTS;
        }
        else if(!strcasecmp(argv[3],"INCL")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::INCL;
        }
        else if(!strcasecmp(argv[3],"POS")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::POS;
        }
        else if(!strcasecmp(argv[3],"RELSIZE")) {
            printf("calculate %s\n",argv[3]);
            featuretype = FeatureExtractor::RELSIZE;
        }
        else if(!strcasecmp(argv[3],"ALL")) {
            printf("calculate %s\n",argv[3]);
            all = true;
        }
        else {
            throw "feature type not implemented yet.";
        }

        autodel<ISegmentLine> segmenter(make_SegmentLineByCCS());

        bytearray image;
        read_image_gray(image,argv[1]);
        bytearray lineimage; // for debugging
        copy(lineimage,image); // for debugging
        autodel<FeatureExtractor> extractor(make_FeatureExtractor());
        extractor->setImage(lineimage);
        extractor->setLineInfo(0,19);

        make_page_black(image);
        intarray segmentation;
        segmenter->charseg(segmentation,image);
        write_png_rgb(stdio(argv[2],"wb"),segmentation);

        make_line_segmentation_black(segmentation); 
        narray<rectangle> bboxes;
        bounding_boxes(bboxes,segmentation);

        floatarray feature;
        bytearray img;
        bytearray subimage;
        for(int i=1;i<bboxes.length();i++) {
            feature.clear();
            if(all) {
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::RELSIZE);
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::POS);
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::BAYS);
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::GRAD);
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::INCL);
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::IMAGE);
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::SKEL);
                extractor->appendFeatures(feature,bboxes(i),FeatureExtractor::SKELPTS);
            }
            else {
                extractor->getFeatures(feature,bboxes(i),featuretype);
            }
            crop(subimage,lineimage,bboxes(i));
            if(all) {
                extractor->appendFeatures(feature,subimage,FeatureExtractor::RELSIZE);
                extractor->appendFeatures(feature,subimage,FeatureExtractor::POS);
                extractor->appendFeatures(feature,subimage,FeatureExtractor::BAYS);
                extractor->appendFeatures(feature,subimage,FeatureExtractor::GRAD);
                extractor->appendFeatures(feature,subimage,FeatureExtractor::INCL);
                extractor->appendFeatures(feature,subimage,FeatureExtractor::IMAGE);
                extractor->appendFeatures(feature,subimage,FeatureExtractor::SKEL);
                extractor->appendFeatures(feature,subimage,FeatureExtractor::SKELPTS);
            }
            else {
                extractor->getFeatures(feature,subimage,featuretype);
            }
            feat2image(img,feature);
        }
    }
    catch(const char *oops) {
        fprintf(stderr,"oops: %s\n",oops);
    }

    return 0;
}
