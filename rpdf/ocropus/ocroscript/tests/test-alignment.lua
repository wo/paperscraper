dofile 'utest.lua'
require 'lib.util'

-- dinit(800,800)

image = bytearray()
read_image_gray(image,"images/line.png")
make_page_black(image)

truth = intarray()
read_png_rgb(truth,"images/line.seg.png")
dshowr(truth,"yY")

function bpnet_alignment(image)
    local bpnet = ocropus_make_RecognizeLine('bpnet', 'models/neural-net-file.nn');
    local fst = make_StandardFst()
    bpnet:recognizeLine(fst,image)
    local s = nustring()
    fst:bestpath(s)
    fst:clear()
    costs = floatarray()
    costs:resize(s:length())
    narray.fill(costs, 0)
    ids = intarray()
    ids:resize(s:length())
    narray.fill(ids, 0)
    fst:setString(s, costs, ids)
    local result = intarray()
    local costs = floatarray()
    bpnet:align(s, result, costs, image, fst)
    return result
end

function tesseract_alignment(segmentation,image)
    local tesseract = make_TesseractRecognizeLine()
    local fst = make_StandardFst()
    local seg = intarray()
    tesseract:recognizeLine(seg, fst, image)
    make_line_segmentation_white(seg)
    return seg
end

bpnet_cseg = bpnet_alignment(image)
dshowr(bpnet_cseg,"Yy")
segmentation = intarray()
segmenter = make_CurvedCutSegmenter()
segmenter:charseg(segmentation, image)
dshowr(segmentation,"yy")
if not tesseract then
    print "Tesseract is disabled, we can't test it."
else
    tesseract_cseg = tesseract_alignment(segmentation,image)
    dshowr(tesseract_cseg,"YY")
end

over,under,mis = evaluate_segmentation(0,0,0,truth,bpnet_cseg,50)
test_assert(over==0 and under==0 and mis==0,"bpnet forced alignment")
if tesseract then
    over,under,mis = evaluate_segmentation(0,0,0,truth,tesseract_cseg,50)
    test_assert(over==0 and under==0 and mis==0,"tesseract forced alignment (should be no over/under/mis-segmentation)")
end

dwait()
