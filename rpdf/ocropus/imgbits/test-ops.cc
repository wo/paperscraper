// Copyright 2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
// or its licensors, as applicable.
// Copyright 1992-2007 Thomas M. Breuel
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
// Project: imgbits
// File: test-ops.cc
// Purpose:
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org


/* Copyright (c) Thomas M. Breuel */

#include <stdlib.h>
#include <map>
#include "narray.h"
#include "narray-util.h"
#include "colib.h"
#include "coords.h"
#include "imgio.h"
#include "io_png.h"
#include "imgbitptr.h"
#include "imgbits.h"
#include "imgrle.h"
#include "imgmisc.h"
#include "imgmorph.h"
#include "imgops.h"
//#include "ocrcomponents.h"
#include "dgraphics.h"
using namespace std;
using namespace ocropus;
using namespace imgrle;
using namespace imgio;
using namespace imglib;

enum Ops { ERODE=1, DILATE=2, CLOSE=3, OPEN=4 };

void byte_op(bytearray &result,bytearray &image,int rx,int ry,Ops op) {
    copy(result,image);
    switch(op) {
    case ERODE: erode_rect(result,rx,ry); break;
    case DILATE: dilate_rect(result,rx,ry); break;
    case CLOSE: close_rect(result,rx,ry); break;
    case OPEN: open_rect(result,rx,ry); break;
    default: throw "oops";
    }
}

void bits_op(bytearray &result,bytearray &image,int rx,int ry,Ops op) {
    BitImage bi;
    bits_convert(bi,image);
    switch(op) {
    case ERODE: bits_erode_rect(bi,rx,ry); break;
    case DILATE: bits_dilate_rect(bi,rx,ry); break;
    case CLOSE: bits_close_rect(bi,rx,ry); break;
    case OPEN: bits_open_rect(bi,rx,ry); break;
    default: throw "oops";
    }
    bits_convert(result,bi);
}

void rle_op(bytearray &result,bytearray &image,int rx,int ry,Ops op) {
    RLEImage ri;
    rle_convert(ri,image);
    ri.verify();
    switch(op) {
    case ERODE: rle_erode_rect(ri,rx,ry); break;
    case DILATE: rle_dilate_rect(ri,rx,ry); break;
    case CLOSE: rle_close_rect(ri,rx,ry); break;
    case OPEN: rle_open_rect(ri,rx,ry); break;
    default: throw "oops";
    }
    ri.verify();
    rle_convert(result,ri);
}

const char *files[] = {
    "images/hello.png", 
    "images/dot.png", 
    "images/test.png", 
    "images/twocol.png",
    "images/boundary.png",
    0
};

void compare(bytearray &truth,bytearray &output,int rx,int ry,const char *msg,const char *file,int op) {
    int delta = maxdifference(truth,output,abs(rx),abs(ry));
    if(delta!=0) {
	printf("FAIL %s %s %d %d %d\n",file,msg,rx,ry,op);
        bytearray diff;
        copy(diff,truth);
        difference(diff,output,0,0);
        dshow(diff,"c");
        dwait();
        dclear(0x333333);
    }
}

int main(int argc,char **argv) {
    dinit(700,700);
    for(int i=0;files[i];i++) {
	for(int cpl=0;cpl<2;cpl++) {
	    bytearray image;
	    read_image_binary(image,files[i]);
	    if(cpl) complement(image);
	    for(Ops op=ERODE;op<=OPEN;op=Ops(op+1)) {
		for(int rx=1;rx<19;rx++) {
		    for(int ry=1;ry<19;ry++) {
			bytearray truth;
			byte_op(truth,image,rx,ry,op);
			erase_boundary(truth,abs(rx),abs(ry),(byte)0);
			dshow(truth,"a");
			
			bytearray bi;
			bits_op(bi,image,rx,ry,op);
			compare(truth,bi,rx,ry,"bits",files[i],op);
			erase_boundary(bi,abs(rx),abs(ry),(byte)0);
			dshow(bi,"b");

			bytearray ri;
			rle_op(ri,image,rx,ry,op);
			compare(truth,ri,rx,ry,"rle",files[i],op);
			erase_boundary(ri,abs(rx),abs(ry),(byte)0);
			dshow(ri,"c");
		    }
		}
	    }
	}
    }
}
