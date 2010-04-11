if #arg < 2 then
    print "Usage:\n    ocroscript degrade <input.png> <output.png>"
    os.exit(2)
end
local image = bytearray()
image = read_image_gray_checked(arg[1])
degrade(image)
write_png(arg[2], image)
