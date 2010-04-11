#ifndef h_additions_
#define h_additions_

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
// File: additions.h
// Purpose: new (existing?) functions for narray
// Responsible: rangoni
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de




#include "io_png.h"
#include "narray.h"
using namespace colib;
using namespace imgio;

namespace additions {
	
	
	template<class T>		// Hagen
    bool valid(T &v) {
        for(int i=0;i<v.length1d();i++)
            if(isnan(v.at1d(i)))
                return false;
        return true;
    }
			
	template<class T>
    inline bool is_valid(narray<T> &a) {
        for(int i=0;i<a.length1d();i++) {
            if(isnan(a.at1d(i))) {
                return false;
            }
        }
        return true;
    }
    
	template <class T>
	inline void print(narray<T> &a) {
		printf("[");
		if(a.rank()==1) {
			for(int i=0;i<a.dim(0);i++) {
				printf("%g ", (double)(a(i)));
			}
		} else if(a.rank()==2) {
			for(int i=0;i<a.dim(0);i++) {
				if(i==0) {
					printf("[");
				} else {
					printf(" [");
				}
				for(int j=0;j<a.dim(1);j++) {
					printf("%g ",(double)a(i,j));
				}
				if(i<a.dim(0)-1) {
					printf("\b]\n");
				} else {
					printf("\b]");
				}
			}
		} else {
			printf("print only vectors and matrices\n");
		}
		printf("]\n");
	}

	template <class T>
	inline void print(objlist<narray<T> > &o) {
		printf("[");
		for(int i=0;i<o.length();i++) {
			if(i==0) {
				printf("[");
			} else {
				printf(" [");
			}
			if(o[i].rank()==1) {
				for(int j=0;j<o[i].dim(0);j++) {
					printf("%g ",(double)o[i](j));
				}
			} else {
				printf("print only list of vectors\n");
			}
			if(i<o.length()-1) {
				printf("\b]\n");
			} else {
				printf("\b]");
			}
		}
		printf("]\n");
	}
	
	inline void print(double a) {printf("%g\n", a);}

	inline void range(intarray &v, int a, int b, int step=1) {
		CHECK_ARG(a<b);
		v.resize(b-a);
		for(int i=a;i<b;i+=step) {
			v[i-a] = i;
		}
	}

	template <class T>
	T rowsum(narray<T> &values, int i) {
		CHECK_ARG(values.rank()==2);
		T sum = 0.;
		for(int j=0;j<values.dim(1);j++) {
			sum += values(i,j);
		}
		return sum;
	}

	template <class T>
	T colsum(narray<T> &values, int j) {
		CHECK_ARG(values.rank()==2);
		T sum = 0.;
		for(int i=0;i<values.dim(0);i++) {
			sum += values(i,j);
		}
		return sum;
	}

	template <class T,class S>
	void colmul(narray<T> &values, int j, S cste) {
		CHECK_ARG(values.rank()==2);
		for(int i=0;i<values.dim(0);i++) {
			values(i,j) *= cste;
		}
	}

	template <class T,class S>
	void rowmul(narray<T> &values, int i, S cste) {
		CHECK_ARG(values.rank()==2);
		for(int j=0;j<values.dim(1);j++) {
			values(i,j) *= cste;
		}
	}

	template <class T>
	int colargmax(narray<T> &values, int i) {
		CHECK_ARG(values.rank()==2);
		if(values.dim(1)<1) return -1;
		int mj = 0;
		T mv = values(0,i);
		for(int j=1;j<values.dim(0);j++) {
			T value = values(j,i);
			if(value<=mv) continue;
			mv = value;
			mj = j;
		}
		return mj;
	}

	template <class T>
	T &colmax(narray<T> &values, int j) {
		CHECK_ARG(values.rank()==2);
		return values(colargmax(values,j),j);
	}

	template <class T>
	int colargmin(narray<T> &values, int i) {
		CHECK_ARG(values.rank()==2);
		if(values.dim(1)<1) return -1;
		int mj = 0;
		T mv = values(0,i);
		for(int j=1;j<values.dim(0);j++) {
			T value = values(j,i);
			if(value>mv) continue;
			mv = value;
			mj = j;
		}
		return mj;
	}
	
	template <class T>
	T &colmin(narray<T> &values, int j) {
		CHECK_ARG(values.rank()==2);
		return values(colargmin(values,j),j);
	}
	
	template<class T>
	void col_add(narray<T> &out, narray<T> &vector) {
		CHECK_ARG(out.rank()==2&&vector.rank()==1);
		CHECK_ARG(out.dim(0)==vector.dim(0));
		for(int j=0;j<out.dim(1);j++) {
			for(int i=0;i<out.dim(0);i++) {
				out(i,j) += vector(i);
			}
		}
	}

	template <class T>
	inline void sum(narray<T> &out, narray<T> &in) {
		CHECK_ARG(out.rank()==2&&in.rank()==2);
		CHECK_ARG(out.dim(0)==in.dim(0)&&in.dim(1)==out.dim(1));
		for(int i=0;i<out.length1d();i++) {
			out.at1d(i) += in.at1d(i);
		}
	}

	template <class T>
	inline void colmax_a(narray<T> &out, narray<T> &in) {
		CHECK_ARG(in.rank()==2);
		out.resize(in.dim(1));
		for(int i=0;i<out.dim(0);i++) {
			out.at1d(i) = colmax(in,i);
		}
	}
	
	template <class T>
	inline void colmin_a(narray<T> &out, narray<T> &in) {
		CHECK_ARG(in.rank()==2);
		out.resize(in.dim(1));
		for(int i=0;i<out.dim(0);i++) {
			out.at1d(i) = colmin(in,i);
		}
	}
	
	template <class T>
	inline bool is_almost_null(narray<T> &array, T epsilon) {
		for(int i=0;i<array.length1d();i++)
			if(fabs(array.at1d(i))>=epsilon)
				return false;
		return true;
	}

	template <class T>
	void multiply(narray<T> &out, narray<T> &in1, objlist<floatarray> &in2) {
		CHECK_ARG(out.rank()==2);
		CHECK_ARG(in1.dim(1)==in2.length());
		out.resize(in1.dim(0),in2[0].dim(0));
		T s = 0.;
		for(int i=0;i<out.dim(0);i++) {
			for (int j=0;j<out.dim(1);j++) {
				s = 0.;
				for (int k=0;k<in1.dim(1);k++) {
					s += in1(i,k)*in2[k](j);
				}
				out(i,j) = s;
			}
		}
	}
	
	
	//already in OCR utils
	/*template <class T>
	void extract_row(narray<T> &out, narray<T> &in, int row) {
		CHECK_ARG(in.rank()==2);
		CHECK_ARG(row<in.dim(1));
		out.resize(in.dim(1));
		for(int i=0;i<in.dim(1);i++) {
			out(i) = in(row,i);
		}
	}
	
	template <class T>
	void extract_col(narray<T> &out, narray<T> &in, int col) {
		CHECK_ARG(in.rank()==2);
		CHECK_ARG(col<in.dim(0));
		out.resize(in.dim(0));
		for(int i=0;i<in.dim(0);i++) {
			out(i) = in(i,col);
		}
	}*/
	
	template <class T,class S>
	void maximum(narray<T> &out, S cste) {
		for(int i=0;i<out.length1d();i++) {
			out.at1d(i) = max(out.at1d(i),cste);
		}
	}
	
	template <class T>
	T maximum_value(narray<T> &in) {
		T max_v = in.at1d(0);
		for(int i=1;i<in.length1d();i++) {
			max_v = max(max_v, in.at1d(i));
		}
		return max_v;
	}

	template <class T>
	void map_function(colib::narray<T> &out, T (*fun)(T)) {
		for(int i=0;i<out.length1d();i++) {
			out.at1d(i) = (*fun)(out.at1d(i));
		}
	}
	
	template <class T>
	void add(colib::narray<T> &out, T v) {
		for(int i=0;i<out.length1d();i++) {
			out.at1d(i) += v;
		}
	}
	
	template <class T>
	static inline int init_series_s(narray<T> &array1D, const char* string) {
	    unsigned int i,n=0;
	    
	    //skip extra whites at the beginning of the string
	    while (*string == ' ' || *string == '\t') string++;
	    //count number of doubles
	    for (i=0;i<strlen(string);i++) {
	        if (string[i]==' ' || string[i]=='\t') {
	            n++;
	        }
	        while (string[i]==' ' || string[i]=='\t') {
	        	i++;
	        }
	        if (string[i]=='\0') {
	        	n--;
	        }
	    }
	    array1D.resize(n+1);
	    double value;
	    for(i=0;i<n;i++) {
	        sscanf(string, "%lf", &value);
	        array1D[i] = (T)(value);
	        while (*string != ' ' && *string != '\t') string++;
			while (*string == ' ' || *string == '\t') string++;
	    }
	    sscanf(string, "%lf", &value);
	    array1D[i]=(T)(value);
	    return(n);
	}
	
	
    void compute_normalize(objlist<floatarray> &vectors,doublearray &stdev, doublearray &m_x);
    void apply_normalize(objlist<floatarray> &vectors, doublearray &stdev, doublearray &m_x);
    void unapply_normalize(objlist<floatarray> &vectors, doublearray &stdev, doublearray &m_x);
	void unapply_normalize(floatarray &vectors, doublearray &stdev, doublearray &m_x);
    	
    void save_char(bytearray &image, const char* filename);
    void write(FILE* stream, floatarray &input);
	void read(floatarray &output, FILE* stream);
	

}

#endif
