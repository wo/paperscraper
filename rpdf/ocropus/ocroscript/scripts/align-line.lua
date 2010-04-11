-- dinit(800,800)
--recolor = 0

bpfile = os.getenv("bpnet")
if not bpfile then
    bpfile = ocrodata.."models/neural-net-file.nn"
    stream = io.open(bpfile)
    if not stream then return "../data/models/neural-net-file.nn" 
    else stream:close() end
end
bpnet = make_NewBpnetLineOCR(bpfile)

gimage = bytearray()
read_image_gray(gimage,arg[1])

stream = assert(io.open(arg[2]))
transcription = stream:read("*all")
stream:close()

image = bytearray()
narray.copy(image,gimage)
binarize_by_range(image,0.5)
make_page_black(image)

segmentation = intarray()
segmenter = make_CurvedCutSegmenter()
segmenter:charseg(segmentation,image)

-- Given a string, construct an FST that matches the words
-- contained in the string, skipping any non-word characters
-- (spaces, symbols, digits, etc.)

function make_langmod(transcription)
    -- construct an FST for skipping word separators
    wordsep = openfst.fst.StdVectorFst()
    wordsep:AddState()
    wordsep:AddState()
    w = 0.1
    wordsep:AddArc1(0,32,32,w,1)
    wordsep:SetStart(0)
    wordsep:SetFinal(1,0.0)
    w = 2.0
    for sym=33,63 do wordsep:AddArc1(0,sym,32,w,1) end
    for sym=123,127 do wordsep:AddArc1(0,sym,32,w,1) end
    openfst.ClosureStar(wordsep)
    -- now, concatenate the word machines with the separators
    result = wordsep:Copy()
    for word in string.gmatch(transcription,"%a+") do
	wordfst = openfst.as_fst(word)
	openfst.Concat(result,wordfst:Copy())
	openfst.Concat(result,wordsep:Copy())
    end
    return result
end

function print_bestpath(fst)
    result = nustring()
    costs = floatarray()
    ids = intarray()
    openfst.bestpath(result,costs,ids,fst)
    print(result:utf8())
end

function maybe(file)
   stream = os.input(file)
   if stream then
      stream:close()
      return file
   else
      return nil
   end
end

function bpnet_alignment(segmentation,image,transcription)
    local map = idmap()
    local fst_builder = make_FstBuilder()
    bpnet:recognizeLine(fst_builder,map,segmentation,image)
    fst = fst_builder:take()
    local ids = intarray()
    local costs = floatarray()
    local result = nustring()
    if false then
        openfst.bestpath(result,costs,ids,fst)
    else
        local langmod = make_langmod(transcription)
	print_bestpath(langmod)
        local ofst = openfst.fst.StdVectorFst()
        openfst.Compose(fst,langmod,ofst)
        if ofst:NumStates()>0 and ofst:NumArcs(0)>0 then
            openfst.bestpath(result,costs,ids,ofst)
        else
            print("FAILED: bpnet alignment")
            return nil
        end
    end
    print("bpnet:",narray.sum(costs))
    print("   ",transcription)
    print("   ",result:utf8())
    local cseg = intarray()
    ocr_result_to_charseg(cseg,map,ids,segmentation)
    return cseg
end

function transcription_errors(s,t)
    if s:len() ~= t:len() then
        return 9999999
    end
    total = 0
    for i=1,s:len() do
        if s:byte(i) ~= t:byte(i) then
            total = total+1
        end
    end
    return total
end

function remove_spaces(result, costs, bboxes)
    local new_result = nustring()
    local new_costs = floatarray()
    local new_bboxes = rectanglearray()
    for i = 0, result:length() - 1 do
        if result:at(i):ord() ~= 32 then -- if not a space
            new_result:push(result:at(i))
            new_costs:push(costs:at(i))
            new_bboxes:push(bboxes:at(i))
        end
    end
    return new_result, new_costs, new_bboxes
end

function tesseract_alignment(segmentation,image,transcription)
    local tesseract = make_tesseract("")
    local result = nustring()
    local costs = floatarray()
    local bboxes = rectanglearray()
    tesseract:recognize_gray(result,costs,bboxes,image)

    actual = string.gsub(result:utf8(),'[^a-zA-Z0-9]','')
    reference = string.gsub(transcription,'[^a-zA-Z0-9]','')
    if transcription_errors(actual,reference)>2 then
        print("FAILED: actual == reference")
        print("    ",actual)
        print("    ",reference)
        return nil
    end
    local cseg = intarray()
    result, costs, bboxes = remove_spaces(result, costs, bboxes)

    ocr_bboxes_to_charseg(cseg,bboxes,segmentation)
    if narray.max(cseg)~=bboxes:length() then
        print("FAILED: max(cseg) == bboxes:length()")
        return nil
    end
    if transcription:gsub(' ',''):len() ~= narray.max(cseg) then
        print("FAILED: transcription:gsub(' ',''):len() == max(cseg)")
        print("    ",transcription)
        print("    ",result:utf8())
        return nil
    end
    return cseg
end

dshowr(segmentation,"yy")

cseg = tesseract_alignment(segmentation,image,transcription)
if cseg==nil then
    cseg = bpnet_alignment(segmentation,image,transcription) 
end
if cseg==nil then
    print("cannot align")
    os.exit(255)
end

dshowr(cseg,"Yy")

-- simple_recolor(bpnet_cseg); simple_recolor(tesseract_cseg)
-- write_png("_thresh.png",image)
-- write_png_rgb("_bpnet_seg.png",bpnet_cseg)
make_line_segmentation_white(cseg)
if recolor then simple_recolor(cseg) end
write_png_rgb(arg[3],cseg)
if arg[4] then
    if recolor then simple_recolor(segmentation) end
    write_png_rgb(arg[4],segmentation)
end

dwait()
