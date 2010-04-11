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
// Project: ocr-tesseract
// File: recognized-page.cc
// Purpose: a part of tesseract.cc that just didn't want to compile together
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de

#include "lines.h"
#include "tesseract.h"

using namespace colib;

namespace ocropus {

    void tesseract_recognize_blockwise(RecognizedPage &result,
                                       ILines &lines,
                                       int pageno) {
        if(pageno >= 0) lines.processPage(pageno);

        double start = now();
        tesseract_recognize_blockwise(result, lines.grayPage(),
                                              lines.segmentation());
        result.setDescription(lines.pageDescription());
        
        double LA_time = lines.getCurrentPageElapsedTime();
        double end = now();
        char buf[1000];
        sprintf(buf, "time elapsed:\n"
                     "  layout analysis: %.2f sec\n"
                     "  recognition: %.2f sec\n"
                     "Total: %.2f sec\n",
                     LA_time, end - start, end - start + LA_time);
        result.setTimeReport(buf);
    }

}
