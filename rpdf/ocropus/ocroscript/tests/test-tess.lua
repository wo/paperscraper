if not tesseract then
    print "Tesseract is disabled, we can't test it."
    os.exit(0)
end

-- check whether tesseract is still working correctly

dofile("utest.lua")

note("trying out tesseract on a block of simple text")

expected = [[This is a lot of 12 point text to test the
ocr code and see if it works on all types
of file format.
The quick brown dog jumped over the
lazy fox. The quick brown dog jumped
over the lazy fox. The quick brown dog
jumped over the lazy fox. The quick
brown dog jumped over the lazy fox.

]]

image = bytearray()
read_image_gray(image,"images/simple.png")
make_page_black(image)
tesseract.init("eng")
result = tesseract.recognize_block(image)
test_assert(expected==result,"tesseract block recognizer")
tesseract.finish()
