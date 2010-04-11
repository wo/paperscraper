require 'lib.util'

local function align_line_by_DOM(aligner, output_dir, image, line_DOM, line_no)
    local line_props = parse_hOCR_title(line_DOM.xarg.title)
    local bbox = parse_rectangle(line_props.bbox, image:dim(1))
    local transcript = get_transcript_by_line_DOM(line_DOM)
    local seg, line = crop_and_align(aligner, image, bbox,
                                     nustring(transcript))
    if seg and transcript then
        make_line_segmentation_white(seg)
        local line_basename = ('%s/%05d'):format(output_dir, line_no)
        write_png_rgb(line_basename .. '.seg.png', seg)
        write_png(line_basename .. '.png', line)
        f = io.open(line_basename .. '.txt', 'w')
        f:write(transcript)
        f:write('\n')
        f:close()
    end
end

function align_page_by_DOM(aligner, hocr_path, output_dir, page_DOM, page_no)
    print(('------------------ PAGE %04d ----------------'):format(page_no))
    local page_dir = string.format('%s/%04d', output_dir, page_no)
    local page_props = parse_hOCR_title(page_DOM.xarg.title)
    local img_rel_path = page_props.image
    if not img_rel_path then
        img_rel_path = string.format('Image_%04d.JPEG', page_no)
    end
    os.execute(('mkdir -p "%s"'):format(page_dir))
    local img_path = combine_paths(hocr_path, img_rel_path)
    local image = bytearray()
    read_image_gray(image, img_path)
    local lines = get_list_of_subitems_by_DOM(page_DOM, 'ocr_line')
    for j = 1, #lines do
        align_line_by_DOM(aligner, page_dir, image, lines[j], j)
    end
end

--- Align a document given the hOCR with the ground truth.
--- Alignment is getting character-level data for training.
--- The image names are either taken from hOCR
--- or, if hOCR lacks them, assumed to be 'Image_####.JPEG'.
--- Requires external program `tidy'.
--- @param aligner An IRecognizeLine that can do align().
--- @param hocr_path Path to ground truth in hOCR format.
--- @param output_dir The directory to put aligned lines.
function align_book(aligner, hocr_path, output_dir)
    print('=============================================')
    print('FORCED ALIGNMENT')
    print('source hOCR: '..hocr_path)
    print('destination: '..output_dir)
    local f = io.popen(string.format('tidy -q -asxml -utf8 "%s"', hocr_path))
    local hocr = xml_collect(f:read('*a'))
    f:close()
    local pages = get_list_of_subitems_by_DOM(hocr, 'ocr_page')
    for i = 1, #pages do
        align_page_by_DOM(aligner, hocr_path, output_dir, pages[i], i - 1)
    end
end


if #arg ~= 2 then
    print("Usage: "..arg[0].." <input hocr> <output dir>")
    os.exit(2)
end

bpnet = ocropus_make_RecognizeLine('bpnet', 'models/neural-net-file.nn')
align_book(bpnet, arg[1], arg[2])
