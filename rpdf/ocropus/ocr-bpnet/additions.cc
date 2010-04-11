

// -*- C++ -*-

// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
// or its licensors, as applicable.
// Copyright 1995-2008 Thomas M. Breuel.
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
// Project: additions to colib functions
// File: additions.cc
// Purpose: new (existing?) functions for narray
// Responsible: rangoni
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "additions.h"

namespace additions {
	
	void write(FILE* stream, floatarray &input) {
		for(int i=0;i<input.length1d();i++) {
			fprintf(stream,"%f\n",input.at1d(i));
		}
	}
	
	void read(floatarray &output, FILE* stream) {
		float value;
		for(int i=0;i<output.length1d();i++) {
			if(fscanf(stream,"%f",&value)!=1) {
				throw "float read error";
				return;
			}
			output.at1d(i) = value;
		}
	}
		
	void save_char(bytearray &image, const char* filename) {
		FILE* f_image = fopen(filename,"wb");
		write_png(f_image, image);
		fclose(f_image);
	}
	
	
	// normalizations functions, Hagen's code
	void compute_normalize(objlist<floatarray> &vectors,doublearray &stdev, doublearray &m_x) {
		CHECK_ARG(stdev.length()==m_x.length());
		int nsamples = vectors.length();
		int ninput = vectors(0).length();
		doublearray m_xx;
		m_x.resize(ninput);
		m_xx.resize(ninput);
		stdev.resize(ninput);
		fill(m_xx, 0.);
		fill(m_x, 0.);
		fill(stdev, 0.);
		for(int d=0;d<ninput;d++) {
			for(int n=0;n<nsamples;n++) {
				m_x(d)  += vectors[n](d);
				m_xx(d) += vectors[n](d) * vectors[n](d);
			}
			m_x(d) /= nsamples;
			m_xx(d) /= nsamples;
			stdev(d) = sqrt(m_xx(d) - m_x(d) * m_x(d));            
		}
		CHECK_ARG(valid(m_x));
		CHECK_ARG(valid(stdev));
	}
	
	void apply_normalize(objlist<floatarray> &vectors, doublearray &stdev, doublearray &m_x) {
		int ninput = m_x.length();
		int nsamples = vectors.length();	
		for(int d=0;d<ninput;d++) {
			for(int n=0;n<nsamples;n++) {
				if(stdev(d)>0) {
					vectors[n](d) = (vectors[n](d)-m_x(d)) / stdev(d);
				} else {
					vectors[n](d) = vectors[n](d)-m_x(d); 
				}
			}
		}
	}
	
	void unapply_normalize(objlist<floatarray> &vectors, doublearray &stdev, doublearray &m_x) {
		int ninput = m_x.length();
		int nsamples = vectors.length();
		for(int d=0;d<ninput;d++) {
			for(int n=0;n<nsamples;n++) {
				if(stdev(d)>0) {
					vectors[n](d) = vectors[n](d)*stdev(d)+m_x(d);
				} else {
					vectors[n](d) = vectors[n](d)+m_x(d);
				}
			}
		}
	}
	
	void unapply_normalize(floatarray &vectors, doublearray &stdev, doublearray &m_x) {
		int ninput = m_x.length();
		int nsamples = vectors.dim(0);
		for(int d=0;d<ninput;d++) {
			for(int n=0;n<nsamples;n++) {
				if(stdev(d)>0) {
					vectors(n,d) = vectors(n,d)*stdev(d)+m_x(d);
				} else {
					vectors(n,d) = vectors(n,d)+m_x(d);
				}
			}
		}
	}

}
