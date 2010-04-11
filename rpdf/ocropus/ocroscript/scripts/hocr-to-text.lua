require 'lib.util'

if #arg ~= 1 then
    print("Usage: ocroscript hocr-to-text input.hocr >output.txt")
    os.exit(1)
end

local f = io.popen(('tidy -q -asxml -utf8 "%s"'):format(arg[1]))
local hocr = xml_collect(f:read('*a'))
f:close()
for page_no, page in pairs(get_list_of_subitems_by_DOM(hocr, 'ocr_page')) do
    for i, line_DOM in pairs(get_list_of_subitems_by_DOM(page, 'ocr_line')) do
        print(get_transcript_by_line_DOM(line_DOM))
    end
end
