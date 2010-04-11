dinit(800,200)

if arg[2]==nil then
    print("usage: ocroscript bpnet.lua nnet-file.nn image.png")
    os.exit(1)
end

image = bytearray:new()
read_image_gray(image,arg[2])
make_page_black(image)

segmentation = intarray:new()
segmenter = make_CurvedCutSegmenter()
segmenter:charseg(segmentation,image)
dshow(image,"y")
dshowr(segmentation,"Y")

lattice = make_FstBuilder()
bpnet = make_NewBpnetLineOCR(arg[1])
components = idmap:new()
bpnet:recognizeLine(lattice,components,segmentation,image)

result = nustring:new()
lattice:bestpath(result)
print(result:utf8())

dwait()
