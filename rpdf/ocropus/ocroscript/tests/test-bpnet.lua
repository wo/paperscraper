dofile("utest.lua")

-- dinit(800,800)

section "image"
image = bytearray()
read_image_gray(image,"images/line.png")
make_page_black(image)

section "bpnet"
if openfst then
    fst = make_FstBuilder()
else    
    fst = make_StandardFst()
end
bpnet = make_NewBpnetLineOCR("../../data/models/neural-net-file.nn")
bpnet:recognizeLine(fst,image)

section "bestpath"
result = nustring()
fst:bestpath(result)
note("bestpath: "..result:utf8())
test_assert(result:utf8()=="This is a lot of 12 point text to test the")

if not openfst then
    print "OpenFST is disabled, we can't test it."
else
    f = fst:take()
    f:Write("_line.fst")
    costs = floatarray()
    ids = intarray()
    openfst.bestpath(result,costs,ids,f)
    note("bestpath: "..result:utf8())
    test_eq(result:utf8(),"This is a lot of 12 point text to test the")
    test_eq(costs:length(),result:length(),"one cost per result character")
    test_eq(ids:length(),result:length(),"one id per result character")

    section "trying to map segments to characters"

    if verbose_test then
        debug_array(costs)
        debug_array(ids)
    end
    -- there should be only one id for each character hypothesis,
    -- and only a small factor of oversegmentation
    test_assert(narray.max(ids)<200,"unreasonably large number of character hypothesis ids")
end

--[[cseg = intarray()
ocr_result_to_charseg(cseg,components,ids,segmentation)
note(narray.max(cseg))
-- narray.max(cseg) doesn't take spaces into account, but id:length() does
-- test_assert(narray.max(cseg)==ids:length())
dshowr(segmentation,"yy")
dshowr(cseg,"yY")
dwait()]]
