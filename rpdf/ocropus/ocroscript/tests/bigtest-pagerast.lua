-- check whether the defined segmenters give the same answer on the test.png image

-- dinit(1800,1000)

dofile("utest.lua")

note "you can visualize segmentations for this test case with something like '-e dinit(1800,1000)'"

segmenter = make_SegmentPageByRAST()

images = {
"images/121colj-150.png",
"images/121colj-200.png",
"images/121colj-300.png",
"images/121colj-400.png",
"images/12col-150.png",
"images/12col-200.png",
"images/12col-300.png",
"images/12col-400.png",
"images/12colj-150.png",
"images/12colj-200.png",
"images/12colj-300.png",
"images/12colj-400.png",
"images/1col-150.png",
"images/1col-200.png",
"images/1col-300.png",
"images/1col-400.png",
"images/1colj-150.png",
"images/1colj-200.png",
"images/1colj-300.png",
"images/1colj-400.png",
"images/2col-150.png",
"images/2col-200.png",
"images/2col-300.png",
"images/2col-400.png",
"images/2colj-150.png",
"images/2colj-200.png",
"images/2colj-300.png",
"images/2colj-400.png",
"images/3col-150.png",
"images/3col-200.png",
"images/3col-300.png",
"images/3col-400.png",
"images/3colj-150.png",
"images/3colj-200.png",
"images/3colj-300.png",
"images/3colj-400.png",
}

-- predict the expected number of columns from the file name

function ncols(file)
    -- note: order matches for these patterns
    if string.find(file,"121col") then return 4 end
    if string.find(file,"12col") then return 3 end
    if string.find(file,"21col") then return 3 end
    if string.find(file,"3col") then return 3 end
    if string.find(file,"2col") then return 2 end
    if string.find(file,"1col") then return 1 end
    return -1
end 

function try_segmentation(file)
    print(string.format("Testing image: %s",file))
    image = bytearray:new()
    tolua.takeownership(image)
    read_image_gray(image,file)
    make_page_binary_and_black(image)
    dshow(image,"x")
    seg = intarray:new()
    tolua.takeownership(seg)
    narray.fill(seg,0)
    segmenter:segment(seg,image)
    if test_success(function () check_page_segmentation(seg) end,
                    "segmenter returned bad segmentation for "..file) then
        pseg_columns(seg)
        dshowr(seg,"X")
        pred = ncols(file)
        actual = narray.max(seg)
        if test_eq(pred,actual,"predicted number of columns differs from actual number for "..file) then
            regions = RegionExtractor:new()
            tolua.takeownership(regions)
            regions:setImageMasked(seg)
            for i = 1,regions:length()-1 do
               b = regions:bbox(i)
               test_greater(b:width(),200,"expected column width")
               test_greater(b:height(),150,"expected column height")
            end
        end
        dwait()
    end
end

for i,file in ipairs(images) do
    try_segmentation(file)
    collectgarbage()
end
