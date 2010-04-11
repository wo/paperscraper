dinit(800,800)

if arg[2]==nil then
    print("usage: ocroscript bpnet.lua nnet-file.nn image.png")
    os.exit(1)
end

pagesegmenter = make_SegmentPageByRAST()
linesegmenter = make_CurvedCutSegmenter()
bpnet = make_NewBpnetLineOCR(arg[1])

page_bin_image = bytearray:new()
page_image = bytearray:new()
line_image = bytearray:new()
line_bin_image = bytearray:new()
pageseg = intarray:new()
lineseg = intarray:new()
components = idmap:new()
result = nustring:new()

pages = Pages:new()
pages:setBinarizer(make_make_BinarizeBySauvola)
-- layout analysis expects images with white background
pages:setAutoInvert(false)
pages:parseSpec(arg[2])

dshow(page_image,"x")

while pages:nextPage() do
   pages:getGray(page_image)

   -- binarize
   pages:getBinary(page_bin_image)
   dshow(page_image,"x")

   -- segment page
   pagesegmenter:segment(pageseg,page_bin_image)
   dshowr(pageseg,"X")

   -- recognize lines
   regions = RegionExtractor:new()
   regions:setPageLines(pageseg)

   for i = 1,regions:length()-1 do
   -- for i = 3,3 do
      regions:extract(line_bin_image,page_bin_image,i,1)
      write_png("line_bin_image.png",line_bin_image)
      make_page_black(line_bin_image)
      linesegmenter:charseg(lineseg,line_bin_image)
      dshow(line_bin_image,"y")
      dshowr(lineseg,"Y")
      -- dwait()
      regions:extract(line_image,page_image,i,1)
      write_png("line_image.png",line_image)
      make_page_black(line_image)
      -- dshow(line_image)
      lattice = make_FstBuilder()
      bpnet:recognizeLine(lattice,components,lineseg,line_image)
      lattice:bestpath(result)
      print(result:utf8())
   end
end

dwait()
