-- -*- lua -*-

image = bytearray()
pages = Pages:new()
pages:parseSpec(arg[1])

dinit(1000,400)

while pages:nextPage() do
   pages:getBinary(image)
   make_page_binary_and_black(image)
   dshow(image,"y")

   cut = make_CurvedCutSegmenter()
   cut_seg = intarray:new()
   cut:charseg(cut_seg,image)
   dshowr(cut_seg,"Y")
   dwait()
end
