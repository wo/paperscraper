-- This script performs a simple one-pass Tesseract recognition
-- through recognize() front-end.

lines = make_Lines(arg[1])
lines:setPageSegmenter(make_SegmentPageByRAST())

segment_line    = make_CurvedCutSegmenter()
recognize_line  = make_TesseractRecognizeLine()
langmod         = make_ShortestPathCharLattice()

for page = 0, lines:pagesCount() - 1 do
    recognized_page = RecognizedPage()
    recognize(recognized_page, lines,
              segment_line, recognize_line,
              langmod, as_IBestPath(langmod),
              page)

    for i = 0, recognized_page:linesCount() - 1 do
        s = nustring()
        recognized_page:text(s, i)
        print(s:utf8())
    end
end

