import libxml2,re,os,string

# convert the HTML to XHTML (if necessary)

os.system("tidy -q -asxhtml < test-page.html > /tmp/test-page.xhtml 2> /dev/null")

# parse the XML

doc = libxml2.parseFile('/tmp/test-page.xhtml')

# search all nodes having a class of ocr_line

lines = doc.xpathEval("//*[@class='ocr_line']")

# a function for extracting the text from a node

def get_text(node):
    textnodes = node.xpathEval(".//text()")
    s = string.join([node.getContent() for node in textnodes])
    return re.sub(r'\s+',' ',s)

# a function for extracting the bbox property from a node
# note that the title= attribute on a node with an ocr_ class must
# conform with the OCR spec

def get_bbox(node):
    data = node.prop('title')
    bboxre = re.compile(r'\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)')
    return [int(x) for x in bboxre.search(data).groups()]

# now, extract the 

for line in lines:
    print get_bbox(line),get_text(line)
