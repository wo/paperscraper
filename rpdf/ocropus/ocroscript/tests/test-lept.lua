dofile("utest.lua")

-- don't run test if leptonica hasn't been linked in
if not lepton then os.exit(0) end

image = lepton.pixRead("images/simple.png")
note("image:",lepton.pixGetWidth(image),lepton.pixGetHeight(image))
image = lepton.pixConvertTo8(image,0)
result = lepton.pixErodeGray(image,5,5) 
lepton.pixWrite("_out.jpg",result,lepton.IFF_JFIF_JPEG)
