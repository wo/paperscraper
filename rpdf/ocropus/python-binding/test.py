from PIL import Image, ImageFont, ImageDraw
import ocropus
from numpy import *


ocropus.eval('''
function get_function_names(module_name)
    local s
    for k,v in pairs(_G[module_name]) do
        if type(v) == 'function' then
            if s then
                s = s .. ' ' .. k
            else
                s = k
            end
        end
    end
    return s
end
''')

# Note: this function shouldn't be inlined because we need it to bound closures.
# (see http://mail.python.org/pipermail/python-list/2005-February/309004.html)
def make_ocropus_closure(name):
    ocropus.__dict__[i] = lambda *args: ocropus.call(name, args)

for i in ocropus.call('get_function_names',('_G',)).split(' '):
    make_ocropus_closure(i)


def render(text, font,w=None,h=130):
    if not w:
        w = h * len(text)
    image = Image.new("L", (w,h), 255)
    draw = ImageDraw.Draw(image)
    # without that space before the text, some letters look cut a little
    draw.text((0, 0), ' ' + text, font=font)
    del draw
    return double(asarray(image))

from pylab import *

a = arange(100).astype('uint8')
ocropus.set('a', a)
ocropus.eval('print(a:length(), a:at(57))')
b = ocropus.get('a')
print b

from scipy import *

a = lena().astype('uint8')
#ocropus.call('gauss2d', (a, 10, 10))
ocropus.gauss2d(a, 5, 5)
imshow(a)
gray()
show()

#font = ImageFont.truetype("/usr/share/fonts/truetype/msttcorefonts/times.ttf")
