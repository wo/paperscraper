-- -*- lua -*-

dinit(800,800)

-- allocate processing modules

noiseremoval = make_DocClean()
deskewer = make_DeskewPageByRAST()
txtimgseg = make_TextImageSeg()
segmenter = make_SegmentPageByRAST()
lineocr = make_tesseract("/dev/null")
lineocr:start_recognizing()

-- allocate working images

image = bytearray:new()
tmpImage = bytearray:new()
pageseg = intarray:new()
line_image = bytearray:new()
line_text = nustring:new()
line_boxes = rectanglearray:new()
line_costs = floatarray:new()

pages = Pages:new()
-- layout analysis expects images with white background
pages:setAutoInvert(false)
pages:parseSpec(arg[1])

while pages:nextPage() do

   -- binarize and remove noise
   pages:getBinary(image)
   dshow(image,"a")
   noiseremoval:cleanup(tmpImage,image)
   dshow(tmpImage,"b")

   -- cleanup
   deskewer:cleanup(image,tmpImage)
   dshow(image,"c")
   -- write_png("desk.png",image)
   -- system("display desk.png &")
   txtimgseg:cleanup(tmpImage,image)
   dshow(tmpImage,"d")
   dwait()

   -- segment
   segmenter:segment(pageseg,tmpImage)
   dshowr(pageseg,"x")

   -- recognize lines
   regions = RegionExtractor:new()
   regions:setPageLines(pageseg)
   for i = 1,regions:length()-1 do
      regions:extract(line_image,image,i,1)
      dshow(line_image,"X")
      lineocr:recognize_binary(line_text,line_costs,line_boxes,line_image)
      print(line_text:utf8())
   end
end

dwait()