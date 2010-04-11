-- This is just some trying of test-* functions
-- (only positive attempts; we cannot afford printing "TEST FAILED"!)

dofile("utest.lua")

--  This is a test for the testing functions themselves
--  Do not be afraid of some stack traces therefore;
--  unless it prints TEST FAILED it should be fine.
test_assert(1)
test_failure(function() assert(nil) end)
test_or_die(1)
