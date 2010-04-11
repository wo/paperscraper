-- -*- lua -*-

dinit(800,800)

segmenter = make_SegmentPageByRAST()
page_image = bytearray()
page_segmentation = intarray()
line_segmenter = make_CurvedCutSegmenter()
line_segmentation = intarray()
line_image = bytearray()
line_text = nustring()
line_boxes = rectanglearray()
line_costs = floatarray()

function tesseract_alignment(segmentation,image)
   if not tesseract_recognizer then
      tesseract_recognizer = make_tesseract("")
   end
   local result = nustring()
   local costs = floatarray()
   local bboxes = rectanglearray()
   tesseract_recognizer:recognize_gray(result,costs,bboxes,image)
   local cseg = intarray()
   ocr_bboxes_to_charseg(cseg,bboxes,segmentation)
   return cseg
end


pages = Pages()
pages:parseSpec(arg[1])

while pages:nextPage() do
   pages:getBinary(page_image)
   segmenter:segment(page_segmentation,page_image)
   dshow(page_image,"a")
   dshowr(page_segmentation,"b")
   regions = RegionExtractor()
   regions:setPageLines(page_segmentation)
   for i = 1,regions:length()-1 do
      regions:extract(line_image,page_image,i,1)
      dshow(line_image,"Yyy")
      line_segmenter:charseg(line_segmentation,line_image)
      dshowr(line_segmentation,"YyY")
      aligned = tesseract_alignment(line_segmentation,line_image)
      dshowr(aligned,"YYy")
      dwait()
   end
end
