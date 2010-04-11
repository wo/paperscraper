--- convenient output functions

verbose_test = os.getenv("verbose_test")

function note(...)
   if verbose_test then 
       print(...)
   end
end

function test_passed(message)
   if verbose_test then
      message = message or "(no details)"
      print("TEST PASSED "..message)
   end
end

function title(message)
   if verbose_test then 
      print("\n=== "..message.." ===\n")
   end
end

function section(message)
   if verbose_test then 
      print("--- "..message.." ---")
   end
end

function complain(level,message)
    local info = debug.getinfo(level)
    local file = info.source
    if string.sub(file,1,1)=="@" then
        file = string.sub(file,2)
    else
        file = "("..file..")"
    end
    print(string.format("%s:%d %s",file,info.currentline,message))
end

-- test whether two values are equal

function test_eq(x,y, message, level)
   local level = level or 0
   local ok = (x==y)
   if not ok then
      message = message or ""
      s = "TEST FAILED "..x.."=="..y.." "
      complain(3+level,s..message)
   else
      test_passed(message)
   end
   return ok
end

-- test whether two values are equal

function test_approx(x,y, message, level, delta)
   delta = delta or 1e-4
   local level = level or 0
   local ok = (x>y-delta) and (x<y+delta)
   if not ok then
      message = message or ""
      s = "TEST FAILED "..x.."=="..y.." "
      complain(3+level,s..message)
   else
      test_passed(message)
   end
   return ok
end

-- test whether a value is greater than a threshold

function test_greater(x,thresh,message, level)
   local level = level or 0
   local ok = (x>thresh)
   if not ok then
      message = message or ""
      s = "TEST FAILED "..x..">"..thresh.." "
      complain(3+level,s..message)
   else
      test_passed(message)
   end
   return ok
end

-- test whether a value is less than a threshold

function test_less(x,thresh,message, level)
   local level = level or 0
   local ok = (x<thresh)
   if not ok then
      message = message or ""
      s = "TEST FAILED "..x.."<"..thresh.." "
      complain(3+level,s..message)
   else
      test_passed(message)
   end
   return ok
end

-- test whether a value is within range

function test_between(x,lo,hi,message, level)
   local level = level or 0
   local ok = 1
   if lo and x<lo then 
       ok = nil 
   end
   if hi and x>hi then
       ok = nil
   end
   if not ok then
      message = message or ""
      s = "TEST FAILED "..(lo or "-inf").."<"..x.."<"..(hi or "+inf").." "
      complain(3+level,s..message)
   else
      test_passed(message)
   end
   return ok
end

-- test case in which the value of x needs to be true

function test_assert(ok, message, level)
   local level = level or 0
   if not ok then
      message = message or "(no further info given)"
      complain(3+level,"TEST FAILED "..message)
   else
      test_passed(message)
   end
   return ok
end

-- like test_assert, but stops testing for this file

function test_or_die(ok,message,level)
   local level = level or 0
   if not ok then
      message = message or "(no further info given)"
      complain(3+level,"TEST FAILED "..message)
   else
      test_passed(message)
   end
end

-- test that the operation completes without error

function test_success(f, message,level)
   local level = level or 0
   if type(f)~="function" then
      error("test_success called with non-function",2)
   end
   message = message or "test for successful completion"
   local ok,value = pcall(f)
   if not ok then
      message = message or "(no further info given)"
      complain(3+level,"TEST FAILED "..message)
   else
      test_passed(message)
   end
   return ok
end

-- test that the operation raises an error

function test_failure(f, message,level)
   local level = level or 0
   if type(f)~="function" then
      error("test_success called with non-function",2)
   end
   local ok,value = pcall(f)
   if ok then
      message = message or "(no further info given)"
      complain(3+level,"TEST FAILED "..message)
   else
      test_passed(message)
   end
   return ok
end
