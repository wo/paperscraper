if #arg < 2 then
    print("usage: ... input output")
    os.exit(1)
end

binarizer = make_BinarizeBySauvola()

input = bytearray:new()
output = bytearray:new()
read_image_gray(input,arg[1])
binarizer:binarize(output,input)
write_png(arg[2],output)
