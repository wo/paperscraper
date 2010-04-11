#ifndef h_feature_extractor_
#define h_feature_extractor_

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

#include "colib.h"

namespace ocropus {
    struct FeatureExtractor {
        colib::bytearray lineimage;
        int basepoint;
        int xheight;
        enum FeatureType {IMAGE=1,GRAD=2,BAYS=3,SKEL=4,
                          SKELPTS=5,INCL=6,POS=7,RELSIZE=8};
        void setImage(colib::bytearray &image);
        void setLineInfo(int basepoint_in,int xheight_in);
        void getFeatures(colib::floatarray &feature,colib::rectangle r,
                         FeatureType ftype);
        void appendFeatures(colib::floatarray &vector,
                            colib::rectangle r,FeatureType ftype);
        void appendFeaturesRescaled(colib::floatarray &vector,int w,int h,
                                    colib::rectangle r,FeatureType ftype);
        void getFeatures(colib::floatarray &feature,colib::bytearray &image,
                         FeatureType ftype);
        void appendFeatures(colib::floatarray &vector,colib::bytearray &image,
                            FeatureType ftype);


        // ______________________________________________________________________


        void calculate_image_feature(colib::floatarray &image_feature,
                                     colib::bytearray &input_image);

        void calculate_grad_feature(colib::floatarray &grady_feature,
                                     colib::bytearray &input_image);

        void calculate_bays_feature(colib::floatarray &bays_feature,
                                    colib::bytearray &input_image);

        void calculate_skel_feature(colib::floatarray &skel_feature,
                                    colib::bytearray &input_image);

        void calculate_skelpts_feature(colib::floatarray &skelpts_feature,
                                       colib::bytearray &input_image);

        void calculate_incl_feature(colib::floatarray &incl_feature,
                                    colib::bytearray &input_image);

        void calculate_pos_feature(colib::floatarray &incl_feature,
                                   colib::bytearray &input_image);

        void calculate_relsize_feature(colib::floatarray &incl_feature,
                                       colib::bytearray &input_image);
    };

    FeatureExtractor *make_FeatureExtractor();
}
#endif
