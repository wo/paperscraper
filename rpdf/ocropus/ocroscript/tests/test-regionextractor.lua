dofile("utest.lua")

image = intarray:new(500,500)

narray.fill(image,0)
image:put(10,10,1)
image:put(10,20,2)
image:put(10,30,3)

r = RegionExtractor:new()
r:setImage(image)
test_eq(4,r:length(),"setImage")

r = RegionExtractor:new()
r:setImageMasked(image)
test_eq(4,r:length(),"setImageMasked")

narray.fill(image,0)
image:put(10,10,pseg_pixel(1,1,1))
image:put(10,20,pseg_pixel(2,1,1))
image:put(10,30,pseg_pixel(3,1,1))
image:put(10,40,pseg_pixel(4,1,1))
image:put(10,50,pseg_pixel(4,1,2))
image:put(10,60,pseg_pixel(4,1,3))

r = RegionExtractor:new()
r:setPageColumns(image)
test_eq(5,r:length(),"setColumns")
