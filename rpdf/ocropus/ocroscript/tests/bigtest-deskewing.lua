
--dinit(1000,1000)

dofile("utest.lua")

deskewer = make_DeskewPageByRAST()

images = {
"images/121colj-300.png",
"images/12col-300.png",
"images/12colj-300.png",
"images/1col-300.png",
"images/1colj-300.png",
"images/2col-300.png",
"images/2colj-300.png",
"images/3col-300.png",
"images/3colj-300.png",
}

skewangles = { 1, -2, 3, -4, 5, -6, 7, -8, 9, }
count = 1

function try_deskewing(file)
    print(string.format("Testing image: %s",file))
    image = bytearray:new()
    tolua.takeownership(image)
    read_image_gray(image,file)
    dshow(image,"a")

    system(string.format("convert -rotate %d %s rotated.png",skewangles[count],file))
    count = count + 1

    rotated = bytearray:new()
    tolua.takeownership(rotated)
    read_image_gray(rotated,"rotated.png")
    dshow(rotated,"b")

    result = bytearray:new()
    tolua.takeownership(result)
    narray.fill(result,0)
    deskewer:cleanup(result,rotated)
    dshow(result,"c")
    dwait()

end

for i,file in ipairs(images) do
    try_deskewing(file)
    collectgarbage()
end
