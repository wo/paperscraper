-- -*- lua -*-

image = bytearray()
pages = Pages:new()
pages:parseSpec(arg[1])

tesseract.init("eng")

while pages:nextPage() do
   pages:getBinary(image)
   dshow(image,"x")

   pagesegmenter = make_SegmentPageByRAST()
   pageseg = intarray:new()
   pagesegmenter:segment(pageseg,image)
   cols = RegionExtractor:new()
   cols:setPageLines(pageseg)
   dshowr(pageseg,"x")

   n = cols:length()-1
   col_image = bytearray:new()

   for i = 1,n do
      cols:extract(col_image,image,i,1);
      dshow(col_image,"X")
      result = tesseract.recognize_block(col_image);
      print(result)
      dwait()
   end

end

dwait()
tesseract.finish()

