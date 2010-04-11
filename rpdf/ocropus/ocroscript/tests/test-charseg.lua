dofile("utest.lua")

-- dinit(800,800)

pages = Pages:new()
image = bytearray:new()
read_image_gray(image,"images/line.png")
make_page_binary_and_black(image)
dshow(image,"yyy")

segmentation = intarray:new()
read_png_rgb(segmentation,"images/line.seg.png")
dshow(segmentation,"YYY")
replace_values(segmentation,hex"ffffff",0)
renumber_labels(segmentation,hex"1001")
make_line_segmentation_black(segmentation)
renumber_labels(segmentation,1)
dshowr(segmentation,"YYy")

reference_seg = segmentation

section "evaluator"

project = make_SegmentLineByProjection()
project_seg = intarray:new()
project:charseg(project_seg,image)
dshowr(project_seg,"yyY")
test_success(function() check_line_segmentation(project_seg) end)
reference_seg = project_seg

note "identical segmentations"

over,under,mis = evaluate_segmentation(0,0,0,reference_seg,reference_seg,0)
note(over,under,mis)
test_assert(over==0)
test_assert(under==0)

note "no segmentation"

no_seg = intarray:new()
narray.copy(no_seg,image)
over,under,mis = evaluate_segmentation(0,0,0,reference_seg,no_seg,0)
note(over,under,mis)
test_assert(over==0)
test_assert(under>30)

note "no segmentation (reverse)"

no_seg = intarray:new()
narray.copy(no_seg,image)
over,under,mis = evaluate_segmentation(0,0,0,no_seg,reference_seg,0)
note(over,under,mis)
test_assert(over>0)
test_assert(under==0)

section "projection"

project = make_SegmentLineByProjection()
project_seg = intarray:new()
project:charseg(project_seg,image)
dshowr(project_seg,"yyY")
test_success(function() check_line_segmentation(project_seg) end)
over,under,mis = evaluate_segmentation(0,0,0,reference_seg,project_seg,0)
note(over,under,mis)
test_assert(over<5)
test_assert(under==0)

section "connected"

connected = make_ConnectedComponentSegmenter()
connected_seg = intarray:new()
connected:charseg(connected_seg,image)
dshowr(connected_seg,"yyY")
check_line_segmentation(connected_seg)
test_success(function ()check_line_segmentation(connected_seg) end)
over,under,mis = evaluate_segmentation(0,0,0,reference_seg,connected_seg,0)
note(over,under,mis)
test_assert(over<5)
test_assert(under==0)

section "ccs"

ccs = make_SegmentLineByCCS()
ccs_seg = intarray:new()
ccs:charseg(ccs_seg,image)
dshowr(ccs_seg,"yYy")
test_success(function() check_line_segmentation(ccs_seg) end)
over,under,mis = evaluate_segmentation(0,0,0,reference_seg,ccs_seg,0)
note(over,under,mis)
test_assert(over<5,"CCS oversegmentation<5 is: "..over)
test_assert(under==0,"CCS undersegmentation==0 is: "..under)

section "cut"

cut = make_CurvedCutSegmenter()
cut_seg = intarray:new()
cut:charseg(cut_seg,image)
dshowr(cut_seg,"yYY")
test_success(function()check_line_segmentation(cut_seg) end)
over,under,mis = evaluate_segmentation(0,0,0,reference_seg,cut_seg,0)
note(over,under,mis)
test_assert(over<30)
test_assert(under==0)

dwait()

