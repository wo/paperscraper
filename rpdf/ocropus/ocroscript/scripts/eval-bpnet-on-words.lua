require 'lib.util'

if #arg ~= 3 then
    print(arg[0].." - evaluate a bpnet classifier on a list of words")
    print("usage: oscroscript "..arg[0].." <dataset> <bpnetfile> <logfile>")
    --print "<bpnetfile> ../data/models/neural-net-file.nn"

    os.exit(1)
end

function plain_text_from_transcript(transcript)
    local s = ""
    for i = 1, #transcript do
        s = s..transcript[i]:utf8()
    end
    return s
end

local c = make_BpnetClassifier()
local cc = make_AdaptClassifier(c)
cc:load(arg[2])

local seg = make_CurvedCutSegmenter()
local ocr = make_NewGroupingLineOCR(cc, seg, false) --if the bpnet contains line info, set to true

total = 0
errors = 0
curent_nb = 0
max_number = 1e30
log = io.open(arg[3],"w")
for line, gt in dataset_entries(arg[1]) do
    gt = plain_text_from_transcript(gt)
    fst = make_StandardFst()
    ocr:recognizeLine(fst, line)
    s = nustring()
    fst:bestpath(s)
    total = total + 1
    if s:utf8() ~= gt then
        errors = errors + 1
        log:write(string.format("%s\t%s\t%s\n", total, s:utf8(), gt))
        print(string.format("%s\t%s\t%s", total, s:utf8(), gt))
        log:flush()
    end
    log:write(string.format("%d word errors among %d  (%g)\n", errors, total, (100.*errors)/total))
    print(string.format("%d word errors among %d  (%g)", errors, total, (100.*errors)/total))
    log:flush()
    curent_nb = curent_nb + 1
    if curent_nb >= max_number then
        break
    end
end
log:close()
