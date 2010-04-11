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
// File: test-jpgpng.cc
// Purpose: interface to corresponding .cc file
// Responsible: tmb
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "colib.h"
#include "imgio.h"


using namespace imgio;
using namespace colib;

void get_random_color_image(bytearray &a) {
    int w = rand()%2000+10;
    int h = rand()%2000+10;
    a.resize(w,h,3);
    int n = a.length1d();
    for(int i=0;i<n;i++) a.at1d(i) = rand()%256; 
}

void read_png_and_assert_equal(intarray &a, const char *path) {
    intarray b;
    read_png_rgb(b,colib::stdio(path,"rb"));
    TEST_ASSERT(equal(a,b));
}

int main(int argc,char **argv) {
    srand(0);
    
    colib::intarray imgrgb ;
    read_jpeg_rgb(imgrgb, "test0.jpg");
    write_png_rgb(stdio("test0.png","wb"), imgrgb) ;
    read_png_and_assert_equal(imgrgb, "test0.png");
    
    read_jpeg_rgb(imgrgb, "test1.jpg");
    write_png_rgb(stdio("test1.png","wb"), imgrgb) ;
    read_png_and_assert_equal(imgrgb, "test1.png");
    
    read_jpeg_rgb(imgrgb, "test2.jpg");
    write_png_rgb(stdio("test2.png","wb"), imgrgb) ;
    read_png_and_assert_equal(imgrgb, "test2.png");
    
    // remove temporary files
    remove("%test0.png");
    remove("%test1.png");
    remove("%test2.png");
    return 0;
}
