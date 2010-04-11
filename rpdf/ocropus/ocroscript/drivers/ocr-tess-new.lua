-- -*- lua -*-

require 'hocr'

output_format = 'hocr'

set_version_string('(Lua script) '..hardcoded_version_string())

image = bytearray()
pages = Pages()
pages:parseSpec(arg[1])

tesseract.init("eng")

if output_format == 'hocr' then
    output_hOCR_header()
end

while pages:nextPage() do
    pages:getBinary(image)
    dshow(image,"x")

    pagesegmenter = make_SegmentPageByRAST()
    pageseg = intarray()
    pagesegmenter:segment(pageseg,image)
    cols = RegionExtractor()
    cols:setPageColumns(pageseg)
    dshowr(pageseg,"x")

    n = cols:length()-1
    col_image = bytearray:new()

    p = RecognizedPage()
    p:setLinesCount(n)
    p:setWidth(image:dim(0))
    p:setHeight(image:dim(1))
    p:setDescription(pages:getFileName())

    start = now();
    for i = 1,n do
        cols:extract(col_image,image,i,1)
        dshow(col_image,"X")
        p:setText(nustring(tesseract.recognize_block(col_image)), i - 1)
        bbox = rectangle(cols:x0(i), cols:y0(i), cols:x1(i), cols:y1(i))
        p:setBbox(bbox, i - 1)
        dwait()
    end
    p:setTimeReport(string.format("time: %.2f sec", now() - start))

    if output_format == 'hocr' then
        output_hOCR(p)
    else
        for i = 0, p:linesCount() - 1 do
            s = nustring()
            p:text(s, i)
            print(s:utf8())
        end
    end
end
if output_format == 'hocr' then
    output_hOCR_footer()
end

dwait()
tesseract.finish()

