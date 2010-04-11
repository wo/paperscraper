-- quick check of whether the argument images give a reasonable segmentation
-- use this to identify potentially missegmented document images in large document
-- collectinos

segmenter = make_SegmentPageByRAST()
image = bytearray:new()
seg = intarray:new()
regions = RegionExtractor:new()

function check(file)
    read_image_gray(image,file)
    make_page_binary_and_black(image)
    segmenter:segment(seg,image)
    check_page_segmentation(seg)
    regions:setPageColumns(seg)
    ncols = regions:length()-1
    if ncols<1 then error("too few columns: "..ncols) end
    if ncols>8 then error("too many columns: "..ncols) end
    for i = 1,ncols do
        b = regions:bbox(i)
        if b:width()<200 or b:height()<200 then
            error "bad dimensions for one of the columns"
        end
        -- should check for whether shapes are rectangular
    end
    print(file,"PASSED "..ncols.." columns")
    pseg_columns(seg)
    dshowr(seg)
    dwait()
end

for i,file in ipairs(arg) do
    ok,result = pcall(function() check(file) end)
    if not ok then
        print(file,"FAILED "..result)
    end
end
