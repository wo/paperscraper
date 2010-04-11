-- -*- lua -*-
--
-- Example of using the Tesseract line recognizer together with 
-- OCRopus layout analysis.
-- Note: for better recognition, see rec-tess.lua

if #arg < 1 then
    arg = { "../../data/pages/alice_1.png" }
end

pages = Pages()
pages:parseSpec(arg[1])

segmenter = make_SegmentPageByRAST()
page_image = bytearray()
page_segmentation = intarray()
line_image = bytearray()
bboxes = rectanglearray()
costs = floatarray()
tesseract_recognizer = make_TesseractRecognizeLine()

while pages:nextPage() do
   pages:getBinary(page_image)
   segmenter:segment(page_segmentation,page_image)
   regions = RegionExtractor()
   regions:setPageLines(page_segmentation)
   for i = 1,regions:length()-1 do
      regions:extract(line_image,page_image,i,1)
      fst = make_StandardFst()
      tesseract_recognizer:recognizeLine(fst,line_image)
      result = nustring()
      fst:bestpath(result)
      print(result:utf8())
   end
end
