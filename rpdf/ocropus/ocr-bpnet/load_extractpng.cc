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
// Project:  ocr-bpnet - neural network classifier
// File: train-from-lines-bpnetmixtures.cc
// Purpose: 
// Responsible: Yves Rangoni (rangoni@iupr.dfki.de)
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

#include "mixtures.h"
#include "bpnet.h"
#include "bpnetmixtures.h"
#include "mixtures.cc"
#include "bpnet.cc"
#include "bpnetmixtures.cc"
#include "line-info.h"
#include "ocrinterfaces.h"
#include "bpnet.h"
#include "bpnetline.h"
#include "grouping.h"
#include "segmentation.h"
#include "classify-chars.h"
#include "classify-chars.cc"

using namespace ocropus;
using namespace imgio;
using namespace imglib;
using namespace colib;
using namespace iupr_bpnet;
using namespace iupr_mixtures;
using namespace iupr_bpnet_mixtures;

/// Extract subimages of a color coded segmenation
void extract_subimages(objlist<bytearray> &subimages, narray<rectangle> &bboxes, intarray &segmentation) {
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

#define DIM_X 10		// see in classify-chars, feature-extractor
#define DIM_Y 10

void feat2image(bytearray &image,floatarray &feature) {
	int c=0;
	int DIM_X_NFEAT = feature.length()/DIM_Y;
	image.resize(DIM_X_NFEAT,DIM_Y);
	for(int i=0;i<DIM_X_NFEAT;i++) {
		for(int j=0;j<DIM_Y;j++) {
			image(i,j) = byte(feature(c));
			c++;
		}
	}
}

void output_png(Classifier* c) {
	MixturesClassifier* MC = dynamic_cast<MixturesClassifier*>(c);
	printf("%d %d\n",MC->means.dim(0), MC->means.dim(1));
	bytearray image;
	floatarray f_d;
	char filename[1024];
	for(int i=0;i<MC->means.dim(0);i++) {
		extract_row(f_d,MC->means,i);
		feat2image(image,f_d);
		
		sprintf(filename,"means_%.3d.png",i);
		save_char(image,filename);
	}
}

int main(int argc,char **argv){
	try { 
		if(argc!=2) {
			fprintf(stderr, "usage: ... bpnetmixture-file\n");
			exit(1);
		}
		ICharacterClassifier* ICC = make_AdaptClassifier(make_BpnetMixturesClassifier());
		ICC->load(stdio(argv[1], "rt"));
		LineCharacterClassifier* LC = dynamic_cast<LineCharacterClassifier*>(ICC);
		Classifier* C = LC->classifier.ptr();
		BpnetMixturesClassifier* BMC = dynamic_cast<BpnetMixturesClassifier*>(C);
		output_png(BMC->C_mixtures.ptr());
		printf("load finished\n");
	}
	catch(const char* oops) {
		fprintf(stderr,"oops: %s\n",oops);
	}
	return 0;
}
