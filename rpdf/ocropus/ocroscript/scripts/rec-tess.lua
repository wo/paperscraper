-- Copyright 2006-2008 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
-- or its licensors, as applicable.
-- 
-- You may not use this file except under the terms of the accompanying license.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License"); you
-- may not use this file except in compliance with the License. You may
-- obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Project: ocroscript
-- File: rec-tess.lua
-- Purpose: recognition through Tesseract
-- Responsible: mezhirov
-- Reviewer: 
-- Primary Repository: 
-- Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

require 'lib.util'
require 'lib.headings'
require 'lib.paragraphs'

if not tesseract then
    print "Compiled without Tesseract support, can't continue."
    os.exit(1)
end

opt,arg = getopt(arg)

if #arg == 0 then
    print "Usage: ocroscript rec-tess [--tesslanguage=...] input.png ... >output.hocr"
    os.exit(1)
end

tesseract.init(opt.tesslanguage or os.getenv("tesslanguage") or "eng")
set_version_string(hardcoded_version_string())

segmenter = make_SegmentPageByRAST()
page_image = bytearray()
page_segmentation = intarray()


-- RecognizedPage is a transport object of tesseract_recognize_blockwise().
-- This function will convert it to PageNode (see lib/hocr)
function convert_RecognizedPage_to_PageNode(p)
    page = PageNode()
    page.width = p:width()
    page.height = p:height()
    page.description = p:description()
    for i = 0, p:linesCount() - 1 do
        local bbox = p:bbox(i)
        local text = nustring()
        p:text(text, i)
        page:append(LineNode(bbox, text))
    end
    return page
end

document = DocumentNode()
for i = 1, #arg do
    pages = Pages()
    pages:parseSpec(arg[i])
    while pages:nextPage() do
        pages:getBinary(page_image)
        segmenter:segment(page_segmentation,page_image)
        local p = RecognizedPage()
        tesseract_recognize_blockwise(p, page_image, page_segmentation)
        p = convert_RecognizedPage_to_PageNode(p)
        p.description = pages:getFileName()

        local regions = RegionExtractor()
        regions:setPageLines(page_segmentation)
        p.headings = detect_headings(regions, page_image)
        p.paragraphs = detect_paragraphs(regions, page_image)
        document:append(p)
    end
end
document:hocr_output()
