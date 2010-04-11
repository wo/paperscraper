-- tries to convert a string to a callable, if not possible, tries print(...)
function custom_loadstring(line)
    local f, errmsg, errmsg2
    f, errmsg = loadstring(line)
    if f then
        return f
    else
        return loadstring('print('..line..')'), errmsg
    end
end

function eval(line)
    local f, errmsg
    f, errmsg = custom_loadstring(line)
    if not f then
        print('SYNTAX ERROR: '..errmsg)
    end
    local result
    result, errmsg = pcall(f)
    if not result then
        print('ERROR: '..errmsg)
    end
end

--------------------------------------------

for line in readline do
    eval(line)
end
print() -- to see shell prompt on a new line
