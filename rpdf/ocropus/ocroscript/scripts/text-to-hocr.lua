require 'lib.hocr'

if #arg ~= 1 then
    print("Usage: "..arg[0].." <input.txt>")
end


document = DocumentNode()
page = PageNode()
page.description = arg[0]
for line in io.lines(arg[1]) do
    if line ~= "" then
        page:append(LineNode(nil --[[we don't know bbox]], nustring(line)))
    end
end
document:append(page)
document:hocr_output()
