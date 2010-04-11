// Copyright 2006 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
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

#ifndef h_imgio_
#define h_imgio_

#include "io_png.h"
#include "io_pbm.h"
#include "io_jpeg.h"
#include "autoinvert.h"

namespace imgio {

    void read_image_gray(colib::bytearray &, const char *path,
            const char *format = NULL);
    void read_image_gray(colib::bytearray &image, FILE *f,
            const char *format = NULL);

    void read_image_binary(colib::bytearray &, const char *path,
            const char *format = NULL);
    void read_image_binary(colib::bytearray &image, FILE *f,
            const char *format = NULL);

}

#endif
