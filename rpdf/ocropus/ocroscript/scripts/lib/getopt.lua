options = {}
if 1 then
    local narg = {}
    for i,v in ipairs(arg) do
        local start,_,key,value = string.find(v,"^[-][-](%w+)=(.+)$")
        if start then
            options[key] = value
        else
            local start,_,key = string.find(v,"^[-][-](%w+)$")
            if start then
                options[key] = 1
            else
                local start,_ = string.find(v,"^[-]")
                if start then
                    for i=2,v:len() do
                        key = string.sub(v,i,i)
                        options[key] = 1
                    end
                else
                    table.insert(narg,v)
                end
            end
        end
    end
    arg = narg
end
