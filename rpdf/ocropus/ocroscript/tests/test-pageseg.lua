-- check whether the defined segmenters give the same answer on the test.png image

-- dinit(1000,1000)

dofile("utest.lua")

function verify(b,s)
    if not b then
        note("FAILED: "..s)
    end
end

image = bytearray:new()
read_image_gray(image,"images/simple.png")
make_page_black(image)

note("1cp")
seg1 = intarray:new()
narray.fill(seg1,9999)
segmenter1 = make_SegmentPageBy1CP()
segmenter1:segment(seg1,image)
check_page_segmentation(seg1)
simple_recolor(seg1)
test_assert(seg1,"a")
dshow(seg1,"a")

note("rast")
seg2 = intarray:new()
narray.fill(seg2,9998)
segmenter2 = make_SegmentPageByRAST()
segmenter2:segment(seg2,image)
check_page_segmentation(seg2)
simple_recolor(seg2)
dshow(seg2,"b")
test_assert(narray.equal(seg1,seg2),"rast differs from 1cp")

note("smear")
seg3 = intarray:new()
narray.fill(seg3,9997)
segmenter3 = make_SegmentPageBySmear()
segmenter3:segment(seg3,image)
check_page_segmentation(seg3)
simple_recolor(seg3)
dshow(seg3,"c")
test_assert(narray.equal(seg1,seg3),"smear differs from 1cp")
dwait()
