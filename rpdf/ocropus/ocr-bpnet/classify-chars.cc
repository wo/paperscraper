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
// Project:
// File:
// Purpose:
// Responsible: kapry
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "classmap.h"
#include "charlib.h"
#include "classify-chars.h"
#include "feature-extractor.h"

using namespace ocropus;
using namespace colib;

namespace {
    void append_our_features(FeatureExtractor &extractor,
                             floatarray &features,
                             bytearray &image,
                             bool with_line_info = true) {
        FeatureExtractor::FeatureType features_to_take[] = {
            FeatureExtractor::BAYS,
            FeatureExtractor::GRAD,
            FeatureExtractor::INCL,
            FeatureExtractor::IMAGE,
            FeatureExtractor::SKEL,
            FeatureExtractor::SKELPTS,
            FeatureExtractor::RELSIZE
        };

        for(int i = 0; i < sizeof(features_to_take)/sizeof(int); i++) {
            extractor.appendFeatures(features, image, features_to_take[i]);
        }
        if(with_line_info)
            extractor.appendFeatures(features, image, FeatureExtractor::POS);
    }
}

struct LineCharacterClassifier : ICharacterClassifier {
    autodel<Classifier> classifier;
    ClassMap map;
    autodel<FeatureExtractor> extractor;
    bool output_garbage;
    objlist<nustring> variants;
    floatarray costs;
    int ninput;
    bool init;

    virtual void set(bytearray &in) {
        variants.clear();
        costs.clear();
        floatarray features;
        append_our_features(*extractor, features, in, false);
        floatarray result;
        classifier->score(result, features);
        for(int i = 0; i < result.length(); i++) {
            if (output_garbage || map.get_ascii(i) != GARBAGE) {  // if not garbage; is this a kluge?
                variants.push().push(nuchar(map.get_ascii(i)));
                costs.push(-log(result[i]));
            }
        }
    }

    virtual void set(bytearray &in,
                     int baseline, int xheight, int descender, int ascender) {
        variants.clear();
        costs.clear();
        floatarray features;
        extractor->setLineInfo(baseline,xheight);
        append_our_features(*extractor, features, in);
        floatarray result;
        classifier->score(result, features);
        for(int i = 0; i < result.length(); i++) {
            if (output_garbage || map.get_ascii(i) != GARBAGE) {  // if not garbage; is this a kluge?
                variants.push().push(nuchar(map.get_ascii(i)));
                costs.push(-log(result[i]));
            }
        }
    }

    virtual void cls(nustring &result, int i) {
        copy(result, variants[i]);
    }

    virtual float cost(int i) {
        return costs[i];
    }

    virtual int length() {
        ASSERT(variants.length() == costs.length());
        return variants.length();
    }

    virtual void load(FILE *stream) {
        map.load(stream);
        classifier->load(stream);
        init = true;
    }

    virtual void save(FILE *stream) {
        map.save(stream);
        classifier->save(stream);
    }

    virtual const char *description() {
        return "character classifier";
    }

    LineCharacterClassifier(Classifier *c, bool garbage):
        classifier(c), extractor(make_FeatureExtractor()),
        output_garbage(garbage),
        ninput(-1),
        init(false) {
    }

    virtual void addTrainingChar(bytearray &image,int base_y, int xheight_y, int descender_y,
		                 int ascender_y,nustring &characters) {
        if(characters.length() != 1) {
            throw "NIY (FIXME)";
        }
        floatarray features;
        extractor->setLineInfo(base_y, xheight_y - base_y);
        append_our_features(*extractor, features, image);
        ninput = features.length();
        if(init) {
            int cls = map.get_class_no_add(characters[0].ord());
            if(cls!=-1) {
                classifier->add(features, cls);
            }
        }
        else {
            int cls = map.get_class(characters[0].ord());
            classifier->add(features, cls);
        }
    }

    virtual void addTrainingChar(bytearray &image, nustring &characters) {
        if(characters.length() != 1) {
            throw "NIY (FIXME)";
        }
        floatarray features;
        append_our_features(*extractor, features, image, false);
        ninput = features.length();
        if(init) {
            int cls = map.get_class_no_add(characters[0].ord());
            if(cls!=-1) {
                classifier->add(features, cls);
            }
        }
        else {
            int cls = map.get_class(characters[0].ord());
            classifier->add(features, cls);
        }
    }
    
    virtual void startTraining(const char *type) {
        classifier->start_training();
    }

    virtual void finishTraining() {
        if(!init) {
            classifier->param("ninput",ninput);
            classifier->param("noutput", map.length());
        }
        classifier->start_classifying();
        init = true;

    }
};

namespace ocropus {

#if 0
    void train(ICharacterClassifier *classifier, const char *path_file_list_segmentation,
                       const char *path_file_list_grid,bool garbage) {

        autodel<ICharacterLibrary> charlib;

        stdio file_list_segmentation_fp = stdio(path_file_list_segmentation,"r");
        while(1) {
            char path[1000];
            if(fscanf(file_list_segmentation_fp,"%s", path) != 1)
                break;
            printf("creating segmentation charlib: %s\n",path);
            charlib = make_segmentation_charlib(path);
            for(int i = 0; i < charlib->sectionsCount(); i++) {
                charlib->switchToSection(i);
                if(charlib->charactersCount() == 0) continue;
                nustring c(1);
                for(int j = 0; j < charlib->charactersCount(); j++) {
                    c[0] = nuchar(charlib->character(j).code());
                    classifier->addTrainingChar(charlib->character(j).image(),
                                                charlib->character(j).baseline(),
                                                charlib->character(j).xHeight() + charlib->character(j).baseline(),
                                                charlib->character(j).descender(),
                                                charlib->character(j).ascender(),
                                                c);
                }
                printf("done with section %d\n", i);
            }
        }

        stdio file_list_grid_fp = stdio(path_file_list_grid,"r");
        while(1) {
            char path[1000];
            if(fscanf(file_list_grid_fp,"%s", path) != 1)
                break;
            printf("creating grid charlib: %s\n",path);
            charlib = make_grid_charlib(path,garbage);
            for(int i = 0; i < charlib->sectionsCount(); i++) {
                charlib->switchToSection(i);
                if(charlib->charactersCount() == 0) continue;
                nustring c(1);
                for(int j = 0; j < charlib->charactersCount(); j++) {
                    c[0] = nuchar(charlib->character(j).code());
                    classifier->addTrainingChar(charlib->character(j).image(),
                                                charlib->character(j).baseline(),
                                                charlib->character(j).xHeight() + charlib->character(j).baseline(),
                                                charlib->character(j).descender(),
                                                charlib->character(j).ascender(),
                                                c);
                    
                }
                printf("extracted features from section %d\n", i);
            }
        }
    }

#endif
    void train(ICharacterClassifier &classifier, ICharacterLibrary &charlib) {
        for(int i = 0; i < charlib.sectionsCount(); i++) {
            charlib.switchToSection(i);
            nustring c(1);
            for(int j = 0; j < charlib.charactersCount(); j++) {
                c[0] = nuchar(charlib.character(j).code());
                classifier.addTrainingChar(charlib.character(j).image(),
                                           charlib.character(j).baseline(),
                                           charlib.character(j).xHeight() + charlib.character(j).baseline(),
                                           charlib.character(j).descender(),
                                           charlib.character(j).ascender(),
                                           c);
            }
            printf("done with section %d\n", i);
        }
    }

    ICharacterClassifier *make_AdaptClassifier(Classifier *c, bool garbage) {
        return new LineCharacterClassifier(c, garbage);
    }
}
