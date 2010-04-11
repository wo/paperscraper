-- -*- lua -*-

image = bytearray()
pages = Pages:new()
pages:parseSpec(arg[1])

dinit(1400,800)

while pages:nextPage() do
   pages:getBinary(image)
   dshow(image,"x")

   pagesegmenter = make_SegmentPageByRAST()
   pageseg = intarray:new()
   pagesegmenter:segment(pageseg,image)
   dshowr(pageseg,"X")
end

dwait()

