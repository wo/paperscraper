
--  dinit(1000,1000)

dofile("utest.lua")

noiseremoval = make_DocClean()

function outimage(file)
    -- note: order matches for these patterns
    if string.find(file,"S001BIN") then return "cleanup-images/S001BIN-clean.png" end
    if string.find(file,"S002BIN") then return "cleanup-images/S002BIN-clean.png" end
    if string.find(file,"S00BBIN") then return "cleanup-images/S00BBIN-clean.png" end
    if string.find(file,"S01EBIN") then return "cleanup-images/S01EBIN-clean.png" end
    if string.find(file,"S03LBIN") then return "cleanup-images/S03LBIN-clean.png" end
    return "-1"
end 

images = {
"cleanup-images/S001BIN.png",
"cleanup-images/S002BIN.png",
"cleanup-images/S00BBIN.png",
"cleanup-images/S01EBIN.png",
"cleanup-images/S03LBIN.png",
}

function try_txtimgseg(file)
    image = bytearray:new()
    tolua.takeownership(image)
    read_image_binary(image,file)
         
    note("Original result")
    result = outimage(file)
    resultimage = bytearray:new()
    tolua.takeownership(resultimage)
    read_image_binary(resultimage,result)
    dshow(resultimage,"a")

    note("Obtained result")
    seg = bytearray:new()
    tolua.takeownership(seg)
    narray.fill(seg,0)
    noiseremoval:cleanup(seg,image)
    dshow(seg,"b")
    dwait()

    test_assert(narray.equal(seg,resultimage),"result differs from original")
end

for i,file in ipairs(images) do
    try_txtimgseg(file)
    collectgarbage()
end
