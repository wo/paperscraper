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
// Project: imgio -- reading and writing images
// File: imgio.cc
// Purpose: reading image files determining their format automatically
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include "imgio.h"


using namespace colib;

namespace imgio {

bool is_pnm(FILE *in) {
    int magic1 = fgetc(in);
    int magic2 = fgetc(in);
    rewind(in);
    return magic1 == 'P' && magic2 >= '1' && magic2 <= '6';
}

bool is_png(FILE *in) {
    char magic[] = {137, 80, 78, 71, 13, 10, 26, 10};
    char buf[sizeof(magic)];
    fread(buf, sizeof(buf), 1, in);
    rewind(in);
    return !memcmp(magic, buf, sizeof(buf));
}

bool is_jpeg(FILE *in) {
    int magic1 = fgetc(in);
    int magic2 = fgetc(in);
    rewind(in);
    return magic1 == 0xff && magic2 == 0xd8;
}

void read_image_gray(bytearray &image, FILE *f, const char *format) {
    if (format) {
        if (!strcasecmp(format, "jpg") || !strcasecmp(format, "jpeg"))
            read_jpeg_gray(image, f);
        else if (!strcasecmp(format, "png"))
            read_png(image, f, true);
        else if (!strcasecmp(format, "pnm"))
            read_pnm_gray(f, image);
        else
            throw "unknown format";
    } else {
        if (is_jpeg(f))
            read_jpeg_gray(image, f);
        else if (is_png(f))
            read_png(image, f, true);
        else if (is_pnm(f))
            read_pnm_gray(f, image);
        else
            throw "file format not recognized";
    }
}

void read_image_gray(bytearray &image, const char *path, const char *format) {
    return read_image_gray(image, stdio(path, "rb"), format);
}

void read_image_binary(bytearray &image,FILE *stream,const char *format) {
    read_image_gray(image,stream,format);
    float threshold = (min(image)+max(image))/2.0;
    for(int i=0;i<image.length1d();i++)
        image.at1d(i) = (image.at1d(i)<threshold)?0:255;
}

void read_image_binary(bytearray &image,const char *path,const char *format) {
    read_image_binary(image, stdio(path, "rb"), format);
}

};
