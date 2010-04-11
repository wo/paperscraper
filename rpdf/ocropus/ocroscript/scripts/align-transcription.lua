require "getopt"

if #arg<2 or #arg>5 then
    print("usage: ... [-v] lineimage textfile cseg [rseg [costfile]]")
    os.exit(1)
end

--------------------------------------------------------------------------------

local function write_costs(file,prefix,costs)
    stream = io.open(file,"w")
    for i=0,costs:length()-1 do
	stream:write(string.format("%s %3d %8g\n",prefix,i,costs:at(i)))
    end
    stream:close()
end

-- Given a string, construct an FST that matches the words
-- contained in the string, skipping any non-word characters
-- (spaces, symbols, digits, etc.)
local function make_langmod(transcription)
    -- construct an FST for skipping word separators
    local wordsep = openfst.fst.StdVectorFst()
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
    local result = wordsep:Copy()
    print("skip_cost junk_cost")
    for word in string.gmatch(transcription,"%a+") do
       wordfst = openfst.as_fst(word,10.0,10.0)
       openfst.Concat(result,wordfst:Copy())
       openfst.Concat(result,wordsep:Copy())
    end
    return result
end

local function print_bestpath(prefix,fst)
    local result = nustring()
    costs = floatarray()
    ids = intarray()
    openfst.bestpath(result,costs,ids,fst)
    print(prefix,result:utf8())
end

local function bpnet_alignment(segmentation,image,transcription)
    local bpfile = os.getenv("bpnet")
    if not bpfile then
        bpfile = ocrodata.."models/neural-net-file.nn"
        stream = io.open(bpfile)
        if not stream then "../data/models/neural-net-file.nn" 
        else stream:close() end
    end
    local bpnet = make_NewBpnetLineOCR(bpfile)
    local map = idmap()
    local fst_builder = make_FstBuilder()
    bpnet:recognizeLine(fst_builder,map,segmentation,image)
    fst = fst_builder:take()
    local ids = intarray()
    costs = floatarray()
    local result = nustring()
    if false then
        openfst.bestpath(result,costs,ids,fst)
    else
        local langmod = make_langmod(transcription)
	print_bestpath("bpnet-bestpath",langmod)
        local ofst = openfst.fst.StdVectorFst()
	openfst.ArcSortOutput(fst)
	openfst.ArcSortInput(langmod)
        openfst.Compose(fst,langmod,ofst)
        if ofst:NumStates()>0 and ofst:NumArcs(0)>0 then
            openfst.bestpath(result,costs,ids,ofst)
        else
            print("FAILED: bpnet alignment")
            return nil
        end
    end
    print("bpnet-total-cost",narray.sum(costs))
    print("bpnet-len",result:dim(0))
    print("bpnet-trans",transcription)
    print("bpnet-aligned",result:utf8())
    local cseg = intarray()
    ocr_result_to_charseg(cseg,map,ids,segmentation)
    return cseg
end

local function transcription_errors(s,t)
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

--------------------------------------------------------------------------------

function align_transcription(options,
                             gray_image_path, 
                             transcription_path, 
                             segmentation_path,
                             oversegmentation_path,
                             costs_path)
    if options["v"] then dinit(800,800) end
    gimage = bytearray()
    read_image_gray(gimage,gray_image_path)

    stream = assert(io.open(transcription_path))
    transcription = stream:read("*all")
    stream:close()

    image = bytearray()
    narray.copy(image,gimage)
    binarize_by_range(image,0.5)
    make_page_black(image)

    segmentation = intarray()
    if options["skel"] then
        segmenter = make_SkelSegmenter()
    elseif options["cut"] then
        segmenter = make_CurvedCutSegmenter()
        print("cut min_thresh=10.0")
        segmenter:set("min_thresh",10.0)
        segmenter:set("debug",arg[1]..".cut_dbg.png")
    else
        print("please specify one of --skel or --cut")
        os.exit(1)
    end
    segmenter:charseg(segmentation,image)

    cseg = bpnet_alignment(segmentation,image,transcription) 

    if cseg==nil then
        print("cannot align")
        os.exit(255)
    end

    make_line_segmentation_white(cseg)

    if options["r"] then simple_recolor(cseg) end
    write_png_rgb(segmentation_path,cseg)

    if oversegmentation_path then
        if options["r"] then simple_recolor(segmentation) end
        write_png_rgb(oversegmentation_path,segmentation)
    end

    if costs_path and costs then
        write_costs(costs_path,"cost",costs)
    end

    dwait()
end

align_transcription(options, unpack(arg))
