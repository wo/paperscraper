dofile("utest.lua")

title "new ocrinterfaces"

section "nustring"

null = nustring()
test_assert(null:utf8()~=nil)
test_assert(null:utf8()=="")

empty = nustring("")
test_assert(empty:utf8()~=nil)
test_assert(empty:utf8()=="")

s = "hello, world"
str = nustring(s)
test_assert(str:length()==string.len(s))
test_assert(str:utf8()==s)


section "StandardFst::bestpath"

fst = make_StandardFst()
costs = floatarray(str:length()); narray.fill(costs,0.0)
ids = intarray(str:length()); narray.fill(ids,0)
fst:setString(str,costs,ids)
result = nustring()
fst:bestpath(result)
note(result:utf8())
test_assert(result:utf8()==s)

if not openfst then
    print "OpenFST is disabled, we can't test it."
else
    section "FstBuilder"

    builder = make_FstBuilder()
    builder:setString(str,costs,ids)
    result = nustring()
    builder:bestpath(result)
    note("bestpath: "..result:utf8())
    test_assert(result:utf8()==s)
    -- do it a second time to make sure it clears
    builder:bestpath(result) 
    test_assert(result:utf8()==s)
    if nil then
        fst = builder:take()
        fst:Write("test.fst")
        result = io.open("_result"):read("*a")
        note("["..s.."]")
        note("["..result.."]")
        test_assert(result==s)
    end

    builder = make_FstBuilder()
    states = {}
    for i=1,10 do states[i] = builder:newState() end
    for i=1,9 do
        state = states[i]
        state1 = states[i+1]
        for j=1,10 do
            cost = 2.0
            if j==i then cost = 1.0 end
            builder:addTransition(state,state1,j+64,cost,i)
        end
    end
    builder:setStart(states[1])
    builder:setAccept(states[10],0.0)
    result = nustring()
    builder:bestpath(result)
    note("bestpath: "..result:utf8())
    test_assert(result:utf8()=="ABCDEFGHI")
end

if not tesseract then
    print "Tesseract is disabled, we can't test it."
else
    section "TesseractRecognizeLine"

    image = bytearray()
    read_image_gray(image,"images/line.png")
    tess = make_TesseractRecognizeLine()
    note(tess:description())
    result = nustring()
    tess:recognizeLine(fst,image)
    -- dshowr(segmentation); dwait()
    fst:bestpath(result)
    -- note that the expected result contains an error; this will
    -- hopefully get fixed as Tesseract's line recognizer improves
    expected_result = "This is a lot 0f 12 point text to test the"
    test_assert(result:utf8()==expected_result)
end

if tesseract and openfst then
    section "TesseractRecognizeLine (with FstBuilder)"

    fst_builder = make_FstBuilder()
    tess:recognizeLine(fst_builder,image)
    fst_builder:bestpath(result)
    note(result:utf8())
    test_assert(result:utf8()==expected_result)
end
