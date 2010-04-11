-- This script performs two-pass recognition with Tesseract
-- through recognize() front-end.


-- well, this is a bit crazy, I know...
function get_option(a, b, default)
    if b then
        -- get both options
        local r_a = get_option(a, nil, b)
        local r_b = get_option(b, nil, a)
        if r_a and r_b then
            error(string.format(
                "From '%s' and '%s', at most one option should be given!",
                a, b))
        end
        if r_a then
            return a
        elseif r_b then
            return b
        else
            return default
        end
    else
        for i = 1, #arg do
            if arg[i] == '--'..a then
                table.remove(arg, i)
                return a
            end
        end
        local env = os.getenv(a)
        if env == '1' or env == 'yes' or env == 'true' then
            return a
        end
        if env == '0' or env == 'no' or env == 'false' then
            return default
        end
    end
end

mode = get_option('blockwise', 'linewise', 'blockwise')
output_format = get_option('hocr', 'text', 'hocr')

set_version_string('(Lua script; mode: '..mode..
                   ') '..hardcoded_version_string())

if #arg ~= 1 then
    print("Usage: ocroscript ocr-adaptive-new.lua [--hocr|--text] [--blockwise|--linewise] <input file>")
    os.exit(1)
end

--------------------------------------------------------------------------------

lines = make_Lines(arg[1])
lines:setPageSegmenter(make_SegmentPageByRAST())

if mode == 'linewise' then
    segment_line    = make_CurvedCutSegmenter()
    recognize_line1 = make_TesseractRecognizeLine()
    recognize_line2 = make_TesseractRecognizeLine()
    train_chars     = make_TesseractTrainChars()
    langmod1        = make_ShortestPathCharLattice()
    langmod2        = make_ShortestPathCharLattice()
    bestpath1       = make_DictBestPath(
                        as_IBestPath(langmod1),
                        make_Aspell())
end

if output_format == 'hocr' then
    output_hOCR_header()
end

for page = 0, lines:pagesCount() - 1 do
    recognized_page = RecognizedPage()
    if mode == 'blockwise' then
        tesseract_recognize_blockwise(recognized_page, lines, page)
    else
        recognize(recognized_page, lines,
                  segment_line, recognize_line1,
                  langmod1, bestpath1,
                  train_chars,
                  recognize_line2,
                  langmod1, as_IBestPath(langmod1),
                  50, -- training threshold
                  page)
    end
    detect_headlines(recognized_page, lines)
    detect_paragraphs(recognized_page, lines)

    if output_format == 'hocr' then
        output_hOCR(recognized_page)
    else
        for i = 0, recognized_page:linesCount() - 1 do
            s = nustring()
            recognized_page:text(s, i)
            print(s:utf8())
        end
    end
end

if output_format == 'hocr' then
    output_hOCR_footer()
end
