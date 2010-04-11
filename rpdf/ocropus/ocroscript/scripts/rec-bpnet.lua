-- -*- lua -*-

-- dinit(800,800)

require 'hocr'
require 'headings'
require 'paragraphs'

function note(s)
   -- print("["..s.."]")
end

if #arg < 1 then
    arg = { "../data/pages/alice_1.png" }
end

pages = Pages()
pages:parseSpec(arg[1])

segmenter = make_SegmentPageByRAST()
page_image = bytearray()
page_segmentation = intarray()
line_image = bytearray()
local bpfile = os.getenv("bpnet")
if not bpfile then
   bpfile = ocrodata.."models/neural-net-file.nn"
   stream = io.open(bpfile)
   if not stream then "../data/models/neural-net-file.nn" 
   else stream:close() end
end
local bpnet = make_NewBpnetLineOCR(bpfile)

--langmod = openfst.Read("2gram.fst")

document = DocumentNode()
while pages:nextPage() do
   pages:getBinary(page_image)
   segmenter:segment(page_segmentation,page_image)
   dshow(page_image,"a")
   dshowr(page_segmentation,"b")
   regions = RegionExtractor()
   regions:setPageLines(page_segmentation)
   page = PageNode()
   page.width = page_image:dim(0)
   page.height = page_image:dim(1)
   page.description = pages:getFileName()

   for i = 1,regions:length()-1 do
      regions:extract(line_image,page_image,i,1)
      dshow(line_image,"Yyy")
      note "line segmentation"
      fst_builder = make_FstBuilder()
      bpnet_recognizer:recognizeLine(fst_builder, line_image)
      -- result:setBbox(lines:bbox(i), i)
      --local s = nustring()
      --fst:bestpath(s)
      --result:setText(s, i)
      fst = fst_builder:take()
      local pruned = openfst.fst.StdVectorFst()
      openfst.fst_prune_arcs(pruned,fst,4,5.0,true)
      fst = pruned
      local ids = intarray()
      local costs = floatarray()
      local result = nustring()
      --print("PATH: "..openfst.bestpath(fst))
      openfst.bestpath(result, costs, ids, fst)
      --openfst.bestpath2(result,costs,ids,fst,langmod)
      --print("LANG: "..result:utf8())
      
      local line = LineNode(regions:bbox(i), result)
      page:append(line)
 
      --local cseg = intarray:new()
      --ocr_result_to_charseg(cseg,map,ids,line_segmentation)
      --dshowr(cseg,"YYy")
   end
   page.headings = detect_headings(regions, page_image --[[must be binary]]) 
   page.paragraphs = detect_paragraphs(regions, page_image)
   document:append(page)
end
document:hocr_output()
