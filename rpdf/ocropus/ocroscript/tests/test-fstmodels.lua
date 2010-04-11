if not openfst then
    print "OpenFST is disabled, we can't test it."
    os.exit(0)
end

dofile("utest.lua")

function dfstdraw(fst)
    if verbose_test then openfst.draw(fst) end
end

fst = openfst.fst.StdVectorFst:new()
test_or_die(0==fst:AddState())
test_or_die(1==fst:AddState())
test_or_die(2==fst:AddState())
fst:SetStart(0)
fst:SetFinal(1,0.0)
fst:SetFinal(2,0.0)
fst:AddArc1(0,2,2,10.0,1)
fst:AddArc1(0,1,1,1.0,1)
fst:AddArc1(0,3,3,1.0,2)
fst:AddArc1(0,1,1,2.0,2)
fst:AddArc1(0,1,1,10.0,2)
test_eq(fst:NumStates(),3)
test_eq(fst:NumArcs(0),5)
test_eq(fst:NumArcs(1),0)
test_eq(fst:NumArcs(2),0)

result = openfst.fst.StdVectorFst:new()
openfst.fst_prune_arcs(result,fst,1,0.3,true)
test_eq(2,result:NumArcs(0))
-- FIXME add some tests here

-- check that the pruning function checks that the target is empty
test_failure(function () openfst.fst_prune_arcs(result,fst,1,0.01,true) end)

result = openfst.fst.StdVectorFst:new()
openfst.fst_prune_arcs(result,fst,2,0.15,true)
test_eq(2,result:NumArcs(0))
-- FIXME add some tests here

openfst.fst_add_to_each_transition(fst,0,99,0.0,true)
-- FIXME add some tests here

-- edit distance etc.

edit_dist = openfst.fst_edit_distance(1,1,1)
test_eq(0,openfst.score(edit_dist,"abc"),"edit distance")
test_eq(0,openfst.score("abc",edit_dist,"abc"),"edit distance")
test_eq(1,openfst.score("abc",edit_dist,"abd"),"edit distance")
test_eq(1,openfst.score("bbc",edit_dist,"abc"),"edit distance")
test_eq(1,openfst.score("abcd",edit_dist,"abc"),"edit distance")
test_eq(1,openfst.score("abc",edit_dist,"abcd"),"edit distance")
test_eq(1,openfst.score("abc",edit_dist,"abbc"),"edit distance")
test_eq(1,openfst.score("abbc",edit_dist,"abc"),"edit distance")
test_eq(3,openfst.score("xxx",edit_dist,"abc"),"edit distance")

limited = openfst.fst_limited_edit_distance(2,1.0,2,1.0)
test_eq(0,openfst.score("abc",limited,"abc"),"limited")
test_eq(0,openfst.score("abcde",limited,"abcde"),"limited")
-- FIXME these seem to be failing for some reason
-- test_failure(function () openfst.score("abe",limited,"abcde") end,"limited")
-- test_approx(1,openfst.score("abcde",limited,"abde"),"limited")
-- test_approx(2,openfst.score("abcde",limited,"ace"),"limited")

range = openfst.fst_size_range(3,7)
test_success(function () test_eq(0,openfst.score(range,"abcde"),"fst_size_range") end,"fst_size_range")
ign = openfst.fst_ignoring(utf32("abc"))
test_success(function () test_eq("",openfst.translate(ign,"abc"),"fst_ignoring") end,"fst_ignoring")
test_success(function () test_eq("xx",openfst.translate(ign,"xabcx"),"fst_ignoring") end,"fst_ignoring")
keep = openfst.fst_keeping(utf32("abc"))
test_success(function () test_eq("abc",openfst.translate(keep,"abc"),"fst_keeping") end,"fst_keeping")
test_success(function () test_eq("abc",openfst.translate(keep,"xabcx"),"fst_keeping") end,"fst_keeping")

-- dictionaries

d = openfst.make_DictionaryModel()
d:addWord(as_intarray("hello"),1.0)
d:addWord(as_intarray("hallo"),1.0)
d:addWord(as_intarray("world"),2.0)
d:addWord(as_intarray("this"),0.5)
d:addWord(as_intarray("a"),1.5)
d:addWord(as_intarray("test"),0.75)
fst = d:take()
note(openfst.bestpath(fst))
temp = openfst.fst.StdVectorFst:new()
openfst.Determinize(fst,temp)
fst = temp
openfst.Minimize(fst)
dfstdraw(fst)
test_eq(openfst.bestpath(fst),"this","DictionaryModel")

d = openfst.make_DictionaryModel()
d:addWord(as_intarray("hello"),2.0)
d:addWord(as_intarray("world"),1.5)
d:addWord(as_intarray("this"),4.5)
d:addWord(as_intarray("a"),4.5)
d:addWord(as_intarray("test"),4.75)
fst2 = d:take()
note(openfst.bestpath(fst2))
test_eq(openfst.bestpath(fst2),"world","DictionaryModel")

-- ArcSort and Compose

result = openfst.fst.StdVectorFst:new()
openfst.ArcSortOutput(fst)
openfst.ArcSortInput(fst2)
openfst.Compose(fst,fst2,result)
note(openfst.bestpath(result))
test_eq(openfst.bestpath(result),"hello","Compose")

-- dictionaries with translation

result = openfst.fst.StdVectorFst:new()
d = openfst.make_DictionaryModel()
d:addWordTranscription(as_intarray("hello"),as_intarray("hallo"),1.0)
d:addWordTranscription(as_intarray("world"),as_intarray("welt"),1.0)
d:addWordTranscription(as_intarray("-"),as_intarray("_"),2.0)
translator = d:take()
note(openfst.bestpath(translator))
openfst.ClosureStar(translator)

input = openfst.as_fst("hello-world")
input:Write("_input.fst")

openfst.ArcSortOutput(input)
openfst.ArcSortInput(translator)
openfst.Compose(input,translator,result)
dfstdraw(result)

note(openfst.bestpath(result))
str = nustring:new()
openfst.bestpath(str,result,true) -- copy epsilons
test_assert(str:length()~=10,"there should be epsilons","DictionaryModel")

openfst.bestpath(str,result)
test_eq(str:length(),10)
test_eq(str:utf8(),"hallo_welt")
test_eq(openfst.bestpath(result),"hallo_welt","DictionaryModel")

openfst.RmEpsilon(result)
test_eq(openfst.bestpath(result),"hallo_welt")

ids = intarray:new()
costs = floatarray:new()
openfst.bestpath(str,costs,ids,result,true)
test_eq(as_string(ids),"hello-world")
openfst.bestpath(str,costs,ids,result)
test_eq(as_string(ids),"hello-worl")

-- ngrams

d = openfst.make_NgramModel()
d:addNgram("\1a",0.1)
d:addNgram("\1b",0.2)
d:addNgram("ab",1)
d:addNgram("ba",2)
d:addNgram("aa",3)
d:addNgram("bb",4)
d:addNgram("a\1",0.3)
d:addNgram("b\1",0.4)
fst = d:take()
openfst.RmEpsilon(fst)
ngram = openfst.fst.StdVectorFst:new()
openfst.Determinize(fst,ngram)
dfstdraw(ngram)

result = openfst.fst.StdVectorFst:new()
openfst.ArcSortInput(ngram)

input = openfst.as_fst("abba")
openfst.ArcSortOutput(input)
openfst.Compose(input,ngram,result)
openfst.bestpath(str,costs,ids,result)
note(str:utf8())
test_eq(str:utf8(),"abba")
test_between(narray.sum(costs),7.09,7.11)

input = openfst.as_fst("abbac")
openfst.ArcSortOutput(input)
openfst.Compose(input,ngram,result)
test_failure(function() openfst.bestpath(str,costs,ids,result) end,"no path expected")
