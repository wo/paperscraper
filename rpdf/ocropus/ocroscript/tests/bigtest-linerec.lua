dofile("utest.lua")

-- dinit(800,800)



binarizer = make_BinarizeByRange()
segmenter = make_CurvedCutSegmenter()

tesseract = make_tesseract("")
function recognize_tesseract(image,segmentation)
    -- FIXME remove obsolete ISimpleLineOCR API after switchover
    str = nustring:new()
    costs = floatarray:new()
    bboxes = rectanglearray:new()
    tesseract:recognize_gray(str,costs,bboxes,image)
    return str:utf8()
end

bpnet = make_NewBpnetLineOCR("../../data/models/neural-net-file.nn")
function recognize_bpnet(image,segmentation)
    map = idmap()
    fst = make_StandardFst()
    bpnet:recognizeLine(fst,map,segmentation,image)
    str = nustring:new()
    fst:bestpath(str)
    return str:utf8()
end

recognizers = {
    ["tess"] = recognize_tesseract,
    ["bpnet"] = recognize_bpnet
}

files = {
   ["images/line-blur2.png"] = "This is a lot of 12 point text to test the",
   ["images/line.png"] = "This is a lot of 12 point text to test the",
   ["images/numbers.png"] = "1234567890",
   ["images/caps.png"] = "THE QUICK BROWN FOX",
   ["images/italics.png"] = "the quick brown fox",
   ["images/line-big.png"] = "This is a lot of 12 point text to test the",
   -- ["images/line-blur5.png"] = "This is a lot of 12 point text to test the",
   -- ["images/line-tiny.png"] = "This is a lot of 12 point text to test the",
}

image = bytearray:new()
binary = bytearray:new()
segmentation = intarray:new()

function test_ocr(truth,actual,name,kind)
   truth = string.gsub(truth," ","")
   actual = string.gsub(actual," ","")
   test_eq(truth,actual,name.." "..kind,1)
end

for file,truth in pairs(files) do
    read_image_gray(image,file)
    binarizer:binarize(binary,image)
    make_page_black(binary)
    segmenter:charseg(segmentation,binary)
    for name,recognizer in pairs(recognizers) do
        dshow(image,"yy"); dshowr(segmentation,"Yy"); dwait()
        ok,result = pcall(function () return recognizer(binary,segmentation) end)
        -- note(name,"binary",ok,result)
        test_assert(ok,name.." crash (binary)")
        test_ocr(truth,result,name,"OCR error on "..file.." (binary)")
        ok,result = pcall(function () return recognizer(binary,segmentation) end)
        -- note(name,"gray",ok,result)
        test_assert(ok,name.." crash (gray)")
        test_ocr(truth,result,name,"OCR error on "..file.." (gray)")
    end
end 
