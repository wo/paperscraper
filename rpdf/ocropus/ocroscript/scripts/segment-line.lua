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

require "getopt"

if #arg < 2 then
    print "Usage: ocroscript segment-line <input.png> <output.png>"
end

if options["cut"] then
    segmenter = make_CurvedCutSegmenter()
elseif options["skel"] then
    segmenter = make_SkelSegmenter()
elseif options["cc"] then
    segmenter = make_ConnectedComponentSegmenter()
end

if not segmenter then
    print("must specify --cut, --skel, or --cc")
    os.exit(1)
end

gimage = bytearray()
read_image_gray(gimage,arg[1])
image = bytearray()
narray.copy(image,gimage)
binarize_by_range(image,0.5)
make_page_black(image)

segmentation = intarray:new()
segmenter:charseg(segmentation,image)

make_line_segmentation_white(segmentation)

if options["r"] or options["recolor"] then 
    simple_recolor(segmentation) 
end

write_png_rgb(arg[2],segmentation)
