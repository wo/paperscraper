-- test the rowarrays stuff
-- FIXME write more unit tests
-- (however, this actually exercises most of the functions through the rowsort code anyway)

dofile("utest.lua")

a = floatarray:new()
b = floatarray:new()
while 1 do
    narray.make_random(a,25,1.0)
    a:reshape(5,5)
    if not narray.rowsorted(a) then break end
end
note("got unsorted array")
narray.copy(b,a)
test_assert(narray.equal(a,b))
narray.rowsort(a)
test_assert(not narray.equal(a,b))
