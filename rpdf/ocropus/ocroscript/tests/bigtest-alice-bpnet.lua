-- -*- lua -*-

-- Tests whether we recognize the alice_1.png page correctly without language model.

dofile("utest.lua")

-- dinit(800,800)

pages = Pages()
pages:parseSpec("../../data/pages/alice_1.png")

lines = {}
for line in io.lines("alice_1.txt") do
    table.insert(lines,line)
end

segmenter = make_SegmentPageByRAST()
page_image = bytearray()
page_segmentation = intarray()
line_segmenter = make_CurvedCutSegmenter()
line_segmentation = intarray()
line_image = bytearray()
line_text = nustring()
line_boxes = rectanglearray()
line_costs = floatarray()
bpnet_recognizer = make_NewBpnetLineOCR("../../data/models/neural-net-file.nn")

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
      note "line segmentation"
      line_segmenter:charseg(line_segmentation,line_image)
      dshowr(line_segmentation,"YyY")
      local map = idmap()
      local fst_builder = make_FstBuilder()
      note "recognizeLine"
      bpnet_recognizer:recognizeLine(fst_builder, line_image)
      fst = fst_builder:take()
      pruned = openfst.fst.StdVectorFst()
      openfst.fst_prune_arcs(pruned,fst,4,5.0,true)
      fst = pruned
      local ids = intarray()
      local costs = floatarray()
      local result = nustring()
      local truth = lines[i]
      local output = openfst.bestpath(fst)
      truth = string.gsub(truth,"[^%a%d]","")
      output = string.gsub(output,"[^%a%d]","")
      -- print("T: "..truth); print("O: "..output)
      test_assert(truth==output,string.format("line %d\n   %s\n   %s",i,truth,output))
   end
end
