-- This is an minimalistic example of layout analysis and recognition together.

-- See rec-ltess.lua for an example with binarization.
-- See rec-tess.lua for better recognition script.

require 'lib.util'

if #arg != 1 then
    print("Usage: ocroscript "..arg[0].." <binary-image.png>")
    exit(1)
end

image = read_image_gray_checked(arg[1])
segmenter = make_SegmentPageByRAST()
segmentation = intarray()
segmenter:segment(segmentation, image)

--recognizer = ocropus_make_RecognizeLine('bpnet', 'models/neural-net-file.nn')
recognizer = make_TesseractRecognizeLine()

regions = RegionExtractor()
regions:setPageLines(segmentation)
line_image = bytearray()
for i = 1, regions:length() - 1 do
    regions:extract(line_image, image, i, 1)
    fst = make_StandardFst()
    recognizer:recognizeLine(fst, line_image)
    s = nustring()
    fst:bestpath(s)
    print(s:utf8())
end
