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
// Project:
// File: bpnetmixtures.cc
// Purpose: perform bpnet-mixtures combination
// Responsible: Yves Rangoni (rangoni@iupr.dfki.de)
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "bpnetmixtures.h"
#include "bpnet.h"
#include "mixtures.h"
#include "narray-ops.h"
#include "ocr-utils.h"
#include "additions.h"

using namespace ocropus;
using namespace narray_ops;
using namespace colib;
using namespace additions;

namespace iupr_bpnet_mixtures {
	class BpnetMixturesClassifier : public Classifier {
		public:
			objlist<floatarray> vectors;
			narray<int> classes;

			autodel<Classifier> C_mlp;
			autodel<Classifier> C_mixtures;

			bool filedump;
			char file_name[1000];
			bool init;

			int dimvector;
			bool training;

			int nhidden;                // MLP
			int epochs;
			float learningrate;
			float testportion;
			bool normalize_mlp;
			bool shuffle;
			bool filedump_mlp;

			int ncluster;               // mixtures
			int maxiter;
			float epsilon;
			bool filedump_mixtures;
			bool mixture;
			bool use_normalization_mixtures;
			float sigma_mixture;
			bool autosigma;
			bool bestmixture;
			int kmin;
			int kmax;
			int ntrials;

			int ninput;
			int noutput;
			
			float mixture_strength;
			int debug;

			void init_common() {
				file_name[0] = '\0';
				filedump = false;
				init = false;
				training = false;
				dimvector = -1;
				ninput = -1;
				noutput = -1;
				mixture_strength = 1.;
				debug = 0;
			}

			BpnetMixturesClassifier() {
				init_common();
				C_mlp = make_BpnetClassifier();
				C_mixtures = make_MixturesClassifier();
			}

			BpnetMixturesClassifier(const char* path) {
				init_common();
				strncpy(file_name,path,sizeof(file_name));
				filedump = true;
			}

			BpnetMixturesClassifier(Classifier* MLP, Classifier* Mixtures) {
				init_common();
				C_mlp = MLP;
				C_mixtures = Mixtures;
				training = true;
			}

			BpnetMixturesClassifier(Classifier* MLP, Classifier* Mixtures, const char* path) {
				init_common();
				strncpy(file_name,path,sizeof(file_name));
				filedump = true;
				C_mlp = MLP;
				C_mixtures = Mixtures;
				training = true;
			}

			BpnetMixturesClassifier(FILE* stream_mlp, FILE* stream_mixtures) {
				init_common();
				C_mlp = make_BpnetClassifier();
				C_mixtures = make_MixturesClassifier();
				C_mlp.ptr()->load(stream_mlp);
				C_mixtures.ptr()->load(stream_mixtures);
				training = true;
			}

			BpnetMixturesClassifier(const char* fn_mlp, const char* fn_mixtures) {
				init_common();
				C_mlp = make_BpnetClassifier();
				C_mixtures = make_MixturesClassifier();
				FILE* stream_mlp = fopen(fn_mlp,"rt");
				C_mlp.ptr()->load(stream_mlp);
				fclose(stream_mlp);
				FILE* stream_mixtures = fopen(fn_mixtures,"rt");
				C_mixtures.ptr()->load(stream_mixtures);
				fclose(stream_mixtures);
				training = true;
			}

			void param(const char* name, double value) {
				if      (!strcmp(name,"nhidden"))       nhidden     = int(value);
				else if (!strcmp(name,"epochs"))        epochs      = int(value);
				else if (!strcmp(name,"learningrate"))  learningrate= float(value);

				else if (!strcmp(name,"testportion"))   testportion = float(value);
				else if (!strcmp(name,"normalization_mlp")) normalize_mlp = bool(value);
				else if (!strcmp(name,"shuffle"))       shuffle     = bool(value);
				else if (!strcmp(name,"filedump_mlp"))  filedump_mlp= bool(value);

				else if (!strcmp(name,"ncluster"))      ncluster    = int(value);
				else if (!strcmp(name,"maxiter"))       maxiter     = int(value);
				else if (!strcmp(name,"epsilon"))       epsilon     = value;
				else if (!strcmp(name,"filedump_mixture"))  filedump_mixtures = bool(value);
				else if (!strcmp(name,"mixture"))       mixture     = bool(value);
				else if (!strcmp(name,"normalization_mixtures"))    use_normalization_mixtures = bool(value);
				else if (!strcmp(name,"sigma")) 		sigma_mixture = float(value);
				else if (!strcmp(name,"autosigma"))     autosigma   = bool(value);
				else if (!strcmp(name,"bestmixture"))   bestmixture = bool(value);
				else if (!strcmp(name,"kmin"))          kmin        = int(value);
				else if (!strcmp(name,"kmax"))          kmax        = int(value);
				else if (!strcmp(name,"ntrials"))       ntrials     = int(value);

				else if (!strcmp(name,"ninput"))        ninput      = int(value);       // if want to use train of make_AdaptClassifier
				else if (!strcmp(name,"noutput"))       noutput     = int(value);
					
				else if (!strcmp(name,"mixstrength"))	mixture_strength = float(value);
				else if (!strcmp(name,"debug"))			debug		= int(value);
				else {
					printf("%s\n",name);
					throw "unknown parameter name";
				}
			}

			void add(floatarray &v, int c) {
				CHECK_CONDITION(training);
				ASSERT(valid(v));
				if (ninput<0)
					ninput = v.dim(0);
				else
					CHECK_CONDITION(v.dim(0)==ninput);

				copy(vectors.push(),v);
				classes.push(c);
				ASSERT(vectors.length()==classes.length());

				C_mlp.ptr()->add(v, c);
				C_mixtures.ptr()->add(v, c);
			}

			void score(floatarray &result, floatarray &input) {
				floatarray result_mlp;
				floatarray result_mixtures;
				floatarray input_mlp;
				copy(input_mlp,input);
				floatarray input_mixtures;
				copy(input_mixtures,input);
				C_mlp.ptr()->score(result_mlp, input_mlp);
				C_mixtures.ptr()->score(result_mixtures, input_mixtures);

				float mindist = min(result_mixtures)/(255.*255.);
				//printf("res_mlp");additions::print(result_mlp);printf("%d",argmax(result_mlp));
				//printf("res_mix");additions::print(result_mixtures);
				//printf("min_dist: %g\n",mindist);
				mindist = exp(-sqr(mindist)*mixture_strength);
				//printf("exp_sqr:  %g\n",mindist);

				floatarray temp;
				copy(temp,result_mlp);
				mul(temp,mindist);
				if (debug) {
					//printf("\n");
					//print(result_mlp);
					printf("%g  %g\n",mindist, mixture_strength);
					//print(temp);
				}
				//printf("score:");additions::print(temp);printf("%d",argmax(temp));
				//getc(stdin);
				copy(result,temp);
				//throw "unimplemented";
			}

			void start_training() {
				if (!training) {
					C_mlp.ptr()->param("nhidden",nhidden);
					C_mlp.ptr()->param("epochs",epochs);
					C_mlp.ptr()->param("learningrate",learningrate);
					C_mlp.ptr()->param("testportion",testportion);
					C_mlp.ptr()->param("normalize",normalize_mlp);
					C_mlp.ptr()->param("shuffle",shuffle);
					C_mlp.ptr()->param("filedump",filedump_mlp);

					C_mixtures.ptr()->param("ncluster",ncluster);
					C_mixtures.ptr()->param("maxiter",maxiter);
					C_mixtures.ptr()->param("epsilon",epsilon);
					C_mixtures.ptr()->param("filedump",filedump_mixtures);
					C_mixtures.ptr()->param("mixture",mixture);
					C_mixtures.ptr()->param("normalization",use_normalization_mixtures);
					C_mixtures.ptr()->param("sigma",sigma_mixture);

					C_mixtures.ptr()->param("autosigma",autosigma);
					C_mixtures.ptr()->param("bestmixture",bestmixture);
					C_mixtures.ptr()->param("kmin",kmin);
					C_mixtures.ptr()->param("kmax",kmax);
					C_mixtures.ptr()->param("ntrials",ntrials);
				}
				training = true;
				C_mlp.ptr()->start_training();
				C_mixtures.ptr()->start_training();
			}

			void start_classifying() {
				if(training) {
					C_mlp.ptr()->start_classifying();
					C_mixtures.ptr()->start_classifying();
				}
				training = false;
			}

			void seal() {
				vectors.dealloc();
				classes.dealloc();
			}

			void load(FILE* stream) {
				if(!stream) {
					throw "cannot open input file for bpnetmixtures";
				}
				char temp[64];
				C_mlp.ptr()->load(stream);
				fgets(temp,64,stream);
				fgets(temp,64,stream);
				C_mixtures.ptr()->load(stream);
			}

			void save(FILE* stream) {
				if(!stream) {
					throw "cannot save output file for bpnetmixtures";
				}
				CHECK_CONDITION(!training||filedump);
				C_mlp.ptr()->save(stream);
				fprintf(stream, "**********\n");
				C_mixtures.ptr()->save(stream);
			}
	};
}

namespace ocropus {
	Classifier* make_BpnetMixturesClassifier() {
		using namespace iupr_bpnet_mixtures;
		return new BpnetMixturesClassifier();
	}
	Classifier* make_BpnetMixturesClassifier(Classifier* MLP, Classifier* Mixtures) {
		using namespace iupr_bpnet_mixtures;
		return new BpnetMixturesClassifier(MLP, Mixtures);
	}
	Classifier* make_BpnetMixturesClassifierDumpIntoFile(const char* path) {
		using namespace iupr_bpnet_mixtures;
		return new BpnetMixturesClassifier(path);
	}
	Classifier* make_BpnetMixturesClassifierDumpIntoFile(Classifier* MLP, Classifier* Mixtures, const char* path) {
		using namespace iupr_bpnet_mixtures;
		return new BpnetMixturesClassifier(MLP, Mixtures, path);
	}
	Classifier* make_BpnetMixturesClassifier(FILE* stream_mlp, FILE* stream_mixtures) {
		using namespace iupr_bpnet_mixtures;
		return new BpnetMixturesClassifier(stream_mlp, stream_mixtures);
	}
	Classifier* make_BpnetMixturesClassifier(const char* path_mlp, const char* path_mixtures) {
		using namespace iupr_bpnet_mixtures;
		return new BpnetMixturesClassifier(path_mlp, path_mixtures);
	}
};
