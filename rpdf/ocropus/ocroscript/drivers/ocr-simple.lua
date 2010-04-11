-- This script performs a simple one-pass Tesseract recognition
-- through using ILines and ILineOCR interfaces and ICharLattice::bestpath().

lines = make_Logger(make_Lines(arg[1]))
lines:setPageSegmenter(make_SegmentPageByRAST())

segment_line    = make_Logger(make_CurvedCutSegmenter())
recognize_line  = make_TesseractRecognizeLine()
langmod         = make_ShortestPathCharLattice()

dummy = make_Logger(make_TesseractTrainChars())
lineocr = make_Logger(make_SimpleLineOCR())
lineocr:inject(segment_line)
lineocr:inject(recognize_line)
lineocr:inject(dummy)

for page = 0, lines:pagesCount() - 1 do
    lines:processPage(page)
    for i = 0, lines:linesCount() - 1 do
        gray = bytearray()
        mask = bytearray()
        lines:line(gray, mask, i)
        lineocr:set(gray, mask)
        lineocr:recognize(langmod)
        s = nustring()
        langmod:bestpath(s)
        print(s:utf8())
    end
end
