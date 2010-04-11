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
// File: mixtures.cc
// Purpose: perform mixture clustering
// Responsible: Yves Rangoni (rangoni@iupr.dfki.de)
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "mixtures.h"
#include "narray-ops.h"
#include "ocr-utils.h"
#include "additions.h"

using namespace ocropus;
using namespace narray_ops;
using namespace colib;
using namespace additions;

namespace iupr_mixtures {
	
	#define DONOTRANDOM 0
	
	class MixturesClassifier : public Classifier {
		public:

		bool filedump;
		char file_name[1000];
		bool init;
		int ncluster;
		int maxiter;
		float epsilon;
		int dimvector;
		bool training;
		bool mixture;
		float sigma_mixture;
		bool use_normalization;
		float min_val;
		float max_val;
		bool autosigma;
		bool bestmixture;
		int kmin;
		int kmax;
		int ntrials;
		
		bool trainfromexistingmeans;
		
		int ninput;	
		int noutput;

		objlist<floatarray> vectors;
		narray<float> means;

		void init_common() {
			file_name[0] = '\0';
			filedump = false;
			training = false;
			init = false;
			ncluster = 2;
			maxiter = 1000;
			epsilon = 1e-6;
			dimvector = -1;
			mixture = true;	// otherwise kmeans
			sigma_mixture = 1.0f;
			use_normalization = false;
			min_val = 0.;
			max_val = 255.;
			autosigma = false;
			bestmixture = false;
			kmin = 2;
			kmax = 4;
			ntrials = 5;
			
			trainfromexistingmeans = false;

			ninput = -1;	// if want to use train of make_AdaptClassifier 
			noutput = -1;
		}
		
		MixturesClassifier() {
			init_common();
		}

		MixturesClassifier(const char* path) {
			init_common();
			strncpy(file_name,path,sizeof(file_name));
			filedump = true;
		}

		void param(const char* name, double value) {
			if (!strcmp(name,"ncluster")) ncluster = int(value);
			else if (!strcmp(name,"maxiter")) maxiter = int(value);
			else if (!strcmp(name,"epsilon")) epsilon = value;
			else if (!strcmp(name,"filedump")) filedump = bool(value);
			else if (!strcmp(name,"mixture")) mixture = bool(value);
			else if (!strcmp(name,"normalization"))	use_normalization = bool(value);
			else if (!strcmp(name,"sigma")) sigma_mixture = float(value);
			else if (!strcmp(name,"autosigma"))	autosigma = bool(value);
			else if (!strcmp(name,"bestmixture"))	bestmixture = bool(value);
			else if (!strcmp(name,"kmin"))	kmin = int(value);
			else if (!strcmp(name,"kmax"))	kmax = int(value);
			else if (!strcmp(name,"ntrials")) ntrials = int(value);
					
			else if (!strcmp(name,"ninput")) ninput = int(value);		// if want to use train of make_AdaptClassifier 
			else if (!strcmp(name,"noutput")) noutput = int(value);
			else {
				printf("%s\n",name);
				throw "mixtures: unknown parameter name";
			}
		}

		void add(floatarray &v, int c) {
			if(vectors.length()>0) {
				CHECK_CONDITION(v.dim(0)==dimvector);
			} else {
				dimvector = v.dim(0);
			}
			copy(vectors.push(),v);
		}

		void score(floatarray &result, floatarray &v) {
			CHECK_CONDITION(v.dim(0)==dimvector);
			CHECK_CONDITION((init)&&(!training));
			floatarray input;
			copy(input,v);
			result.resize(dimvector);
			/*if (use_normalization) {	// already applied to the means
				additions::add(input,-(max_val-min_val)/2.f);
				mul(input,1./(max_val-min_val));	
			}*/
			distancestomeans(result,means,input);
			//throw "unimplemented";
		}

		void start_training() {
			training = true;
		}

		void start_classifying() {
			if(training) {
				create();
				if (use_normalization) {
					max_val = -1e30; 
					min_val = 1e30;
					for(int i=0;i<vectors.length();i++) {
						float l_max = max(vectors(i));
						float l_min = min(vectors(i));
						if (l_max>max_val) {
							max_val = l_max;
						}
						if (l_min<min_val) {
							min_val = l_min;
						}
					}
					//printf("%g %g %g %g\n",min_val, max_val, (max_val-min_val)/2.0, (max_val-min_val));
					for(int i=0;i<vectors.length();i++) {
						additions::add(vectors(i),-(max_val-min_val)/2.f);
						mul(vectors(i),1./(max_val-min_val));
					}
				}
				
				if(mixture) {
					if(bestmixture) {
						best_mixture(vectors,kmin,kmax,ntrials,sigma_mixture,autosigma);
					} else{
						fast_gaussian_mixture_fixed(vectors,means,ncluster,maxiter,sigma_mixture,autosigma);	
					}
				} else {
					kmeans2(vectors,means,ncluster,maxiter,epsilon);
				}
				
				
				if (use_normalization) {
					// maybe not necessary
					for(int i=0;i<vectors.length();i++) {
						mul(vectors(i),max_val-min_val);
						additions::add(vectors(i),(max_val-min_val)/2.f);						
					}
					mul(means,max_val-min_val);
					additions::add(means,(max_val-min_val)/2.f);
				}

				init = true;
				if (filedump) {
					save(stdio(file_name, "w"));
				}
			}
			training = false;
			//printf("end\n");
		}

		void seal() {
			vectors.dealloc();
			means.dealloc();
		}

		void save(FILE* stream) {
			CHECK_CONDITION(!training||filedump);
			if(!stream) {
				throw "mixtures: cannot save output file for mixture/kmeans";
			}
			fprintf(stream,"mixtures %d %d %d\n",dimvector,means.dim(0),use_normalization);
			if(use_normalization) {
				fprintf(stream,"%f %f\n", max_val, min_val);
			}
			fprintf(stream,"%f\n", sigma_mixture);
			write(stream,means);
		}

		void load(FILE* stream) {
			CHECK_CONDITION(!training);
			
			double min_val_tmp, max_val_tmp, sigma_tmp;
			int norm_tmp;
			if(!stream) {
				throw "mixtures: cannot read input file for kmeans";
			}

			if((fscanf(stream,"mixtures %d %d %d",&dimvector,&ncluster,&norm_tmp)!=3) ||
				(dimvector<1)||(ncluster<0)) {
				printf("%d %d %d\n", dimvector, ncluster, norm_tmp);
				throw "mixtures: bad input format1";
			}
			use_normalization = bool(norm_tmp);
			create();
			if(use_normalization) {
				fscanf(stream,"%lf %lf",&max_val_tmp,&min_val_tmp);
				max_val = max_val_tmp;
				min_val = min_val_tmp;
			}
			means.resize(ncluster,dimvector);
			if(fscanf(stream,"%lf",&sigma_tmp)!=1) {
				throw "mixtures: bad input format2";
			}
			sigma_mixture = sigma_tmp;
			read(means,stream);

			trainfromexistingmeans = true;
			init = true;
		}

		void create() {
			if(!init) {
				means.resize(ncluster,dimvector);
			}
		}

		void pairdistances(floatarray &dist,floatarray &u,objlist<floatarray> &v) {
			int n = u.dim(0);
			int m = u.dim(1);
			int l = v.length();
			CHECK_CONDITION(m==v[0].dim(0));
			dist.resize(n,l);
			fill(dist,0.);
			for(int i=0;i<n;i++) {
				for(int j=0;j<l;j++) {
					float d = 0;
					for(int k=0;k<m;k++) {
						d += sqr((u(i,k)-v[j](k)));
					}
					dist(i,j) = sqrt(d);
				}
			}
		}

		void distancestomeans(floatarray &dist, floatarray &means, floatarray &input) {
			int n = means.dim(0);
			int m = means.dim(1);
			int l = input.dim(0);
			float d = 0.f;
			CHECK_CONDITION(m==l);
			dist.resize(n);
			fill(dist,0.f);
			for(int i=0;i<n;i++) {
				d = 0.f;
				for(int k=0;k<m;k++) {
					d += sqr((means(i,k)-input(k)));
				}
				dist(i) = sqrt(d);
			}
		}
		
		static float exp_f(float a) { return (float)(exp(a)); }
		static float abs_f(float a) { return (float)(fabs(a)); }
		
		int fast_gaussian_mixture_fixed(objlist<floatarray> &data, narray<float> &means, int k, int maxiter, float &sigma, int auto_sigma) {
			int n = data.length();
			CHECK_CONDITION(n>0&&k<n);
			int d = data[0].dim(0);
			CHECK_CONDITION(d>0);

			if(!trainfromexistingmeans||means.dim(0)==0||means.dim(1)==0) {
				means.resize(k,d);
				
				narray<int> init;
				range(init,0,n);
				if(!DONOTRANDOM) {
					randomly_permute(init);
				}
				for(int i=0;i<k;i++){
					rowcopy(means,i,data[init[i]]);
				}
			}
			
			floatarray r;
			r.resize(k,n);
			fill(r,0.f);
			
			floatarray oldmeans;
			oldmeans.resize(d,k);
			copy(oldmeans,means);

			floatarray dists;
			pairdistances(dists,means,data);
	
			floatarray err;
			err.resize(k,n);
			fill(err,0.f);
			
			floatarray lo;
			floatarray hi;
			floatarray rel;
			floatarray needs_update;
			int iter = 0;
	
			for(iter=0;iter<maxiter;iter++) {
				copy(oldmeans,means);

				if(sigma!=0.) {
					copy(r,dists);
					narray_ops::mul(r,r);
					mul(r,-1./(2.*sqr(sigma)));
					map_function(r,&exp_f);
					maximum(r,1e-45);
					for(int col=0;col<r.dim(1);col++) {
						colmul(r,col,1./colsum(r,col));
					}
				} else {
					fill(r,0.f);
					for(int j=0;j<n;j++) {
						r(colargmin(dists,j),j) = 1.;
					}
				}
				
				multiply(means,r,data);
				for(int i=0;i<k;i++) {
					rowmul(means,i,1./rowsum(r,i));
				}

				if (!is_valid(means)) {
					print(means);
					throw "mixtures: fast_gaussian_mixture_fixed, invalid means";
				}
				floatarray shift;
				shift.resize(k);
				float dist = 0.f;
				for(int i=0;i<k;i++) {
					dist = 0.f;
					for(int j=0;j<means.dim(1);j++) {
						dist += sqr(means(i,j)-oldmeans(i,j));
					}
					shift(i)=sqrt(dist);
				}
				
				col_add(err,shift);


				
				narray_ops::add(lo,dists,err);
				mul(lo,lo);
				mul(lo,-1./(2.*sqr(sigma)));
				map_function(lo,&exp_f);
				
				narray_ops::sub(hi,dists,err);	
				maximum(hi,0.);
				mul(hi,hi);
				mul(hi,-1./(2.*sqr(sigma)));
				map_function(hi,&exp_f);

				colmax_a(rel,dists);
				for(int j=0;j<rel.length1d();j++)
					rel.at1d(j) += (rel.at1d(j) == 0);
				
				sub(needs_update,hi,lo);
				map_function(needs_update,abs_f);
				for(int i=0;i<needs_update.dim(1);i++)
					colmul(needs_update,i,1./rel(i)); 
				for(int j=0;j<needs_update.length1d();j++)
					needs_update.at1d(j) = (needs_update.at1d(j) > 1e-3);
				

				dist=0.f;
				for(int i=0;i<needs_update.dim(0);i++) {
					for(int j=0;j<needs_update.dim(1);j++) {
						if (needs_update(i,j) != 0) {
							dist = 0.f;
							for(int l=0;l<d;l++) {
								dist += sqr(means(i,l)-data[j][l]);
							}
							dist = sqrt(dist);
							dists(i,j) = dist;
							err(i,j) = 0.f; 
						}
					}
				}
				printf("%d\t%g %g %g %g\n",iter,max(shift),max(err),sum(needs_update),sigma);
				if (max(shift)<epsilon) {
					break;
				}
				if(auto_sigma) {
					
					floatarray mindist;
					colmin_a(mindist,dists);

					mul(mindist,mindist);
					float s = sum(mindist);

					sigma = sqrt(s/(mindist.dim(0)*d));

					//printf("not yet implemented\n");
					//throw "not yet implemented\n";
				}
			}
			return iter;
		}
		
		float bic(objlist<floatarray> &data) {
			floatarray llh;
			log_likelihood(llh,data);
			float L = sum(llh);
			int k = means.dim(0)*means.dim(1)+1;
			int n = data.length();
			return -2*abs(L) + k*log(n);
		}
		
		void log_likelihood(floatarray &out, objlist<floatarray> &data) {
			floatarray dists;
			pairdistances(dists,means,data);
			
			mul(dists,dists);
			mul(dists,-1./(2.*sqr(sigma_mixture)));
			
			out.resize(dists.dim(1));
			colmax_a(out,dists);
		}
		
		void best_mixture(	objlist<floatarray> &data, int kmin=2, int kmax=10,
							int ntrials=5, float sigma=1., int autosigma=1) {
			float mbic = 1e38;
			//MixturesClassifier* mmix = NULL;
			printf("best_mixture %d %d\n",kmin,kmax);
			for(int k=kmin;k<=kmax;k++) {
				for(int trial=0;trial<ntrials;trial++) {
					MixturesClassifier* MC = new MixturesClassifier();
					for(int i=0;i<vectors.length();i++) {
						MC->add(vectors[i],0);
					}
					MC->ncluster = k;
					MC->sigma_mixture = sigma;
					MC->autosigma = autosigma;
					MC->epsilon = epsilon;
					MC->maxiter = maxiter;
					MC->use_normalization = use_normalization;

					MC->start_training();
					MC->start_classifying();
				
					float c_bic = MC->bic(MC->vectors);
					printf("bic %d %f\n", k, c_bic);

					if (c_bic < mbic) {
						mbic = c_bic;
						copy(means, MC->means);
						sigma_mixture = MC->sigma_mixture;
					}
					delete MC;
				}
			}
			printf("best mixture for k=%d, bic=%f\n", means.dim(0),mbic);
		}

		int kmeans2(objlist<floatarray> &data, narray<float> &means, int k, int maxiter, float epsilon) {
			int n = data.length();
			CHECK_CONDITION(n>0&&k<n);
			int d = data[0].dim(0);
			CHECK_CONDITION(d>0);
			if(!trainfromexistingmeans||means.dim(0)==0||means.dim(1)==0) {
				means.resize(k,d);
				narray<int> init;
				range(init,0,n);
				if(!DONOTRANDOM) {
					randomly_permute(init);
				}
				for(int i=0;i<k;i++){
					rowcopy(means,i,data[init[i]]);
				}
			}

			narray<float> last;
			last.resize(k,n);

			fill(last,0.f);

			narray<float> diff;
			narray<float> dists;
			narray<float> r;
			narray<float> s;
			narray<int> m;
			r.resize(k,n);
			s.resize(k,1);
			m.resize(n);

			int iter;

			for(iter=0;iter<maxiter;iter++) {
				pairdistances(dists,means,data);

				narray_ops::sub(diff,dists,last);
				if(is_almost_null(diff,epsilon)) {
					break;
				}

				copy(last,diff);

				for(int i=0;i<n;i++) {
					m[i] = colargmin(dists,i);
				}

				fill(r,0.);
				for(int i=0;i<n;i++) {
					r(m[i],i)=1.;
				}

				for(int i=0;i<k;i++) {
					s(i,0)=rowsum(r,i);
				}
				multiply(means,r,data);
				for(int i=0;i<k;i++) {
					for(int j=0;j<data[0].dim(0);j++) {
						means(i,j) /= s(i,0);
					}
				}
				printf("%d/%d, %f\r",iter,maxiter,maximum_value(diff));fflush(stdout);
			}
			printf("\n");
			return iter;
		}
	};
}

namespace ocropus {
	Classifier *make_MixturesClassifier() {
		using namespace iupr_mixtures;
		return new MixturesClassifier();
	}
	Classifier *make_MixturesClassifierDumpIntoFile(const char* path) {
		using namespace iupr_mixtures;
		return new MixturesClassifier(path);
	}
};
