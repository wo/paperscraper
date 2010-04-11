if not openfst then
    print "OpenFST is disabled, we can't test it."
    os.exit(0)
end

dofile("utest.lua")

section "simple creation"
f = openfst.fst.StdVectorFst:new()
f:AddState()
f:SetStart(0)
f:AddArc1(0,1,1,0.5,1)
f:AddArc1(0,2,2,1.5,1)
f:AddState()
f:AddArc1(1,3,3,2.5,2)
f:AddState()
f:SetFinal(2,3.5)

if nil then
   test_failure(f:AddArc1(-1,4,4,1.0,1))	
   test_failure(f:AddArc1(1,4,4,1.0,-1))
   test_failure(f:AddArc1(1000,4,4,1.0,0))
   test_failure(f:AddArc1(0,4,4,1.0,1000))
   test_failure(f:AddArc1(0,4,4,1000))
end

section "copy"
g = f:Copy()
test_assert(openfst.Equivalent(f,g))

section "minimize"
openfst.Minimize(g)
test_assert(openfst.Equivalent(f,g))
g = f:Copy()
h = openfst.fst.StdVectorFst:new()

section "determinize"
openfst.Determinize(g,h)
test_assert(openfst.Equivalent(f,h))

section "rmepsilon"
g = f:Copy()
openfst.RmEpsilon(g)
test_assert(openfst.Equivalent(f,g))
openfst.Concat(g,f)
openfst.RmEpsilon(g)
test_assert(not openfst.Equivalent(f,g))

section "read/write"
f:Write("_binary.fst")
h = openfst.Read("_binary.fst")
note(h)
test_or_die(h)
test_assert(openfst.Equivalent(f,h))

section "non-trivial bestpath"
f = openfst.fst.StdVectorFst:new()
states = {}
for i=1,10 do states[i] = f:AddState() end
for i=1,9 do
    state = states[i]
    state1 = states[i+1]
    for j=1,10 do
        cost = 2.0
        if j==i then cost = 1.0 end
        f:AddArc1(state,j+64,j+64,cost,state1)
    end
end
f:SetStart(states[1])
f:SetFinal(states[10],0.0)
result = nustring:new()
costs = floatarray:new()
ids = intarray:new()
openfst.bestpath(result,costs,ids,f)
note("bestpath: "..result:utf8())
test_assert(result:utf8()=="ABCDEFGHI")
