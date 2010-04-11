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
// File: train-from-lines-mixtures.cc
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
#include "mixtures.cc"
#include "line-info.h"

using namespace ocropus;
using namespace imgio;
using namespace imglib;
using namespace colib;
using namespace iupr_mixtures;

param_int ncluster("ncluster",20,"Number of clusters/means");
param_int maxiter("maxiter",10,"Maximum number of iterations");
param_double epsilon("epsilon",1e-4,"Epsilon, precision of the solution");
param_bool mixture("mixture",true,"Mixture otherwise kmeans");
param_bool filedump("filedump",false,"Dump to file");
param_bool normalization("normalization",true,"Normalization");
param_bool autosigma("autosigma",false,"Find sigma value during training");
param_bool bestmixture("bestmixture",false,"find the best mixture");
param_int kmin("kmin",2,"kmin");
param_int kmax("kmax",4,"kmax");
param_int ntrials("ntrials",5,"ntrails");

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

#define DIM_X 10		// see in classify-chars, feature-extracctor
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
		if(argc!=3) {
			fprintf(stderr, "usage: ... file-list mixture-file");
			exit(1);
		}

		autodel<FeatureExtractor> extractor(make_FeatureExtractor());
		autodel<Classifier> classifier(make_MixturesClassifier());
		classifier->start_training();


		classifier->param("ncluster",ncluster);
		classifier->param("maxiter",maxiter);
		classifier->param("epsilon",epsilon);
		classifier->param("filedump",filedump);
		classifier->param("mixture",mixture);
		classifier->param("normalization",normalization);
		
		classifier->param("autosigma",autosigma);
		classifier->param("bestmixture",bestmixture);
		classifier->param("kmin",kmin);
		classifier->param("kmax",kmax);
		classifier->param("ntrials",ntrials);

		ClassMap map;
		int ninput = -1;

		char trans[1000];
		intarray segmentation;
		objlist<bytearray> subimages;
		narray<rectangle> bboxes;
		int count=1;
		stdio file_list_fp = stdio(argv[1],"r");
		int nblines=0;
		int howmanysubimage = 0;
		while(1) {	// nblines<10
			char path[1000];
			if(fscanf(file_list_fp,"%s", path) != 1)
				break;
			nblines++;  
		
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
				printf("\n%s\n", segmentation_file);
				printf("number of subimages: %d number of characters: "
					   "%d\n",subimages.length(),transcript.length()); 
			}
			if(subimages.length()!=transcript.length()) {
				continue;
			}

			// add data to classifier
			
			for(int i=0;i<subimages.length();i++) {
				floatarray features;
				baseline = intercept+bboxes[i].x0 * slope;
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
				if(debug && (howmanysubimage<100)) {
					char file_name[50];
					sprintf(file_name,"subimage_%06d.png",count);
					write_png(stdio(file_name,"w"),subimages[i]);
					howmanysubimage++;
				}
				count++;
			}
		}
		printf("\n");
		classifier->param("ninput",ninput);
		classifier->param("noutput", map.length());
		
		classifier->start_classifying();

		stdio mixt_fp = stdio(argv[2],"wa");
		map.save(mixt_fp);
		classifier->save(mixt_fp);
		
		if(debug) {
			output_png(classifier.ptr());
		}
	}
	catch(const char* oops) {
		fprintf(stderr,"oops: %s\n",oops);
	}
	return 0;
}
