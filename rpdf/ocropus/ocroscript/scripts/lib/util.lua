require 'lib.hocr'


--- Return a Lua-owned IRecognizeLine of a specified kind (bpnet, for example).
function ocropus_make_RecognizeLine(name, path)
    if name:lower() == 'bpnet' then
        local c = make_BpnetClassifier()
        local cc = make_AdaptClassifier(c)
        if path then
            find_and_load_ICharacterClassifier(cc, path)
        end
        local seg = make_CurvedCutSegmenter()
        local result = make_NewGroupingLineOCR(cc, seg)
        tolua.takeownership(result)
        return result
    else
        error("unknown recognizer name: "..name)
    end
end

--------------------------------------------------------------------------------
-- XML parsing

-- by Roberto Ierusalimschy
-- copied from http://lua-users.org/wiki/LuaXml
-- fixed a bit

local function xml_parseargs(s)
  local arg = {}
  string.gsub(s, "(%w+)%s*=%s*([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  return arg
end

--- Parse XML.
---
--- Each tag is represented as a table with "label", "xarg" and numbered fields:
--- label is the tag name, xarg is the hashtable of tag properties,
--- and numbered fields correspond to the tag content.
---
--- This function is based on code by Roberto Ierusalimschy
--- with minimal changes.
--- Original is at http://lua-users.org/wiki/LuaXml
---
--- @param s The input string containing XML data.
--- @return The DOM tree.
function xml_collect(s)
  local stack = {}
  local top = {}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i, j = 1, 1
  while true do
    ni,j,c,label,xarg, empty = string.find(s, "<(%/?)(%w+)(.-)(%/?)>", i)
    if not ni then break end
    local text = string.sub(s, i, ni-1)
    if not string.find(text, "^%s*$") then
      table.insert(top, text)
    end
    if empty == "/" then  -- empty element tag
      table.insert(top, {label=label, xarg=xml_parseargs(xarg), empty=1})
    elseif c == "" then   -- start tag
      top = {label=label, xarg=xml_parseargs(xarg)}
      table.insert(stack, top)   -- new level
    else  -- end tag
      local toclose = table.remove(stack)  -- remove top
      top = stack[#stack]
      if #stack < 1 then
        error("nothing to close with "..label)
      end
      if toclose.label ~= label then
        error("trying to close "..toclose.label.." with "..label)
      end
      table.insert(top, toclose)
    end
    i = j+1
  end
  local text = string.sub(s, i)
  if not string.find(text, "^%s*$") then
    table.insert(stack[stack.n], text)
  end
  if #stack > 1 then
    error("unclosed "..stack[stack.n].label)
  end
  return stack[1]
end

--------------------------------------------------------------------------------

-- 
function get_transcript_by_line_DOM(line_DOM)
    local function build_list_of_texts(node, list)
        if type(node) == 'string' then
            table.insert(list, node)
        elseif type(node) == 'table' then
            for i = 1, #node do
                build_list_of_texts(node[i], list)
            end
        end
    end
    local list = {}
    build_list_of_texts(line_DOM, list)
    if #list == 0 then return end
    local result = list[1]
    for i = 2, #list do
        result = result .. ' ' .. list[i]
    end
    return (result:gsub('&lt;','<'):gsub('&gt;','>'):gsub('&amp;','&'))
end

function get_list_of_subitems_by_DOM(node, subitem_type)
    local function build_list_of_subitems(node, subitem_type, list)
        if type(node) == 'table' then
            if node.xarg and node.xarg.class == subitem_type then
                table.insert(list, node)
            end
            for i = 1, #node do
                build_list_of_subitems(node[i], subitem_type, list)
            end
        end
    end
    local result = {}
    build_list_of_subitems(node, subitem_type, result)
    return result
end

--------------------------------------------------------------------------------
-- Transcript files

--- Return a table of nustrings that correspond
--- to characters in the segmentation.
--- This function takes a string as might be read from a transcript file.
--- @param s A Lua string with the transcript.
function parse_transcript(s)
    local result = {}
    if s:find('\t') then
        -- tab-separated transcript
        for i in s:gmatch('[^\t]+') do
            table.insert(result, nustring(i))
        end
    else
        -- usual transcript (one unicode char per glyph)
        local t = nustring(s)
        for i = 0, t:length() - 1 do
            s = nustring()
            s:push(t:at(i))
            result[i+1] = s
        end
    end
    return result
end

--- Read a transcript from a file and return an array of nustrings.
--- @param path Path to the file that contains only one line: the transcript.
function read_transcript(path)
    local stream = assert(io.open(path))
    local transcript = parse_transcript(stream:read("*a"):gsub('\n$',''))
    stream:close()
    return transcript
end

--------------------------------------------------------------------------------

-- FIXME: is this transcript to FST or nustring to FST, after all?
function transcript_to_fst(transcript)
    local fst = make_StandardFst()
    tolua.takeownership(fst)
    local s = fst:newState()
    fst:setStart(s)
    --for i = 1, #transcript do
        for j = 0, transcript--[=[[i]]=]:length() - 1 do
            local c = transcript--[=[[i]]=]:at(j)
            if c:ord() == 32 then
                -- add a loop to the current state
                fst:addTransition(s, s, c, 0, 0)
            else
                -- add an arc to the next state
                local t = fst:newState()
                fst:addTransition(s, t, c, 0, 0)
                s = t
            end
        end
    --end
    fst:setAccept(s)
    return fst
end


function parse_rectangle(s, h)
    local x0, y0, x1, y1 = s:match('^%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)%s*$')
    assert(x0 and y0 and x1 and y1, "rectangle parsing error")
    return {x0 = x0+0, y0=h-1-y1, x1=x1+0, y1=h-1-y0}
end

--- Read a word-by-word ground truth
-- (such files are produced by parse-google-hocr.py)
-- @param path Path to the file containing lines of this form: x0 y0 x1 y1 word.
-- @param h Height (required to convert boxes to ocropus's
--                  lower origin convention).
-- @return The list of {x0,y0,x1,y1,gt} tables and a whole line as a string.
function read_words(path, h)
    local transcript = ''
    local words = {}
    for line in io.lines(path) do
        local x0, y0, x1, y1, gt = line:match(
            '^(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(.*)$')
        assert(x0 and y0 and x1 and y1 and gt, "ground truth parsing error")
        -- convert coordinates to numbers and pack into a table
        table.insert(words, {x0=x0+0, y0=h-1-y1, x1=x1+0, y1=h-1-y0, gt=gt})
        transcript = transcript .. ' ' .. gt
    end
    return words, transcript:gsub('^ ','')
end

-- Integer division.
-- Lua would cast the result of diviving two integers to float instead.
local function div(a, b)
    return (a - a % b) / b
end

--- Prepend backslashes before every occurence of the given pattern,
--- and backslashes themselves are transformed into double backslashes.
function escape(s, pattern)
    return (s:gsub('\\', '\\\\'):gsub(pattern, function(x) return '\\'..x end))
end

--- Drop backslash escapes.
function unescape(s)
    return (s:gsub('\\+', function(x) return string.rep('\\', div(#x, 2)) end))
end

--------------------------------------------------------------------------------
-- Alignment

--
function crop_and_align(aligner, image, bbox, transcript)
    local line_image = bytearray()
    local margin = 2
    extract_subimage(line_image, image, bbox.x0 - margin, bbox.y0 - margin,
                                        bbox.x1 + margin, bbox.y1 + margin)
    local chars = nustring()
    local result = intarray()
    local fst = transcript_to_fst(transcript)
    local costs = floatarray()
    aligner:align(chars, result, costs, line_image, fst)
    if chars:length() == 0 then
        print('[FAILURE] ' .. transcript:utf8())
    else
        print(chars:utf8())
    end
    return result, line_image
end

function open_dataset_description_file(path, mode)
    return {
        file = io.open(path, mode),

        write = function(self, type, path, properties)
            assert(type and path and properties)
            assert(type:match("^%w*$")) -- type consists only of alphanumerics
            self.file:write(type..' '..escape(path,'[ ]'))
            for key, value in pairs(properties) do
                self.file:write(' '..key..'="'..escape(value,'["]')..'"')
            end
            self.file:write('\n')
        end,

        read = function(self)
            local s = self.file:read("*l")
            if not s then return end
            local type, path, properties
            type, s = s:match('^%s*(%w*)%s+(.*)$')
            local i = s:gsub('\\\\', '//'):find('[^\\]%s') -- find first non-escaped space
            path = unescape(s:sub(1, i))
            s = s:sub(i+2)
            properties = {}
            
            local aux = s:gsub('\\\\', '//')
            local i = 1
            while true do
                local first_quote = aux:find('[^\\]"', i)
                if not first_quote then break end
                local second_quote = assert(aux:find('[^\\]"', first_quote + 1))
                local key = s:match('^%s*([^=]*)=', i)
                local value = s:sub(first_quote + 2, second_quote)
                i = second_quote + 2
                properties[key] = value
            end
            
            return type, path, properties
        end,

        close = function(self)
            self.file:close()
        end
    }
end


--- Interpret one path as relative to the other.
--- @param a A path to some file lying in the reference directory.
--- @param b A path that we'll interpret as relative to the a's directory.
--- @return dirname(a)..b if b is relative or b if it's absolute.
function combine_paths(a, b)
    assert(a and b)
    if b:match("^/") or b:match("^%a:\\") then
        return b
    elseif not a:match("[/\\]") then -- dirname(a) == .
        return b
    else
        return a:match("^.*[/\\]") .. b
    end
end

--- (obsolete) Align a dataset using the given aligner.
--- @param aligner An IRecognizeLine instance capable of aligning.
--- @param path Path to the dataset description file (the format is not documented; we'll probably stick to something simpler).
--- @param image (optional) The image to use if the dataset doesn't specify it.
function align_dataset(aligner, path, image)
    local stream = assert(open_dataset_description_file(path))
    while true do
        local item_type, item_path, properties = stream:read()
        if not item_type then break end
        
        -- absolutize item_path
        item_path = combine_paths(path, item_path)
        
        if properties and properties.img then
            image = bytearray()
            local image_path = combine_paths(path, properties.img)
            read_image_gray(image, image_path)
        end
        if item_type == 'line' then
            assert(image, 'image not specified')
            local transcript_path
            if properties.transcript then
                transcript_path = combine_paths(path, properties.transcript)
            else
                transcript_path = path:gsub('\\.png$','\\.txt')
            end
            local transcript = read_transcript(transcript_path)
            local seg = crop_and_align(aligner, image,
                           parse_rectangle(properties.bbox, image:dim(1)),
                           transcript)
            make_line_segmentation_white(seg)
            write_png_rgb(item_path, seg)
        else
            align_dataset(aligner, item_path, image)
        end
    end
    stream:close()
end

function parse_hOCR_title(s)
    if not s then return {} end
    local result = {}
    for i in s:gmatch('[^;]+') do
        local key, value = i:match('^%s*([%w]*)%s+(.*)')
        result[key] = value:gsub('%s*$','')
    end
    return result
end

-------------------------------------------------------------------------------

-- take_job() and release_job() are for large-scale data processing.

function take_job(lock_dir, n)
    local f = io.popen('uname -n')
    local info = f:read('*l')
    f:close()
    -- find the first nonreadable file
    for i = 1, n do
        local lock_path = lock_dir..'/'..i
        local success, f = pcall(io.open, lock_path)
        if success and f then
            f:close()
        else
            f = io.open(lock_path, 'a+')
            f:write(info)
            f:close()
            -- now check we're the first
            f = io.open(lock_path)
            local t = f:read('*l')
            f:close()
            if t == info then
                return i
            else
                print "collision!"
                print("we are: "..info)
                print("but the first was: "..t)
            end
        end
    end
end

function release_job(lock_dir, i)
    local lock_path = lock_dir..'/'..i
    f = io.open(lock_path, 'a+')
    f:write('done\n')
    f:close()
end

-------------------------------------------------------------------------------

--- Change the letters that single-character classifier will confuse anyway.
--- @param s The string (in Latin alphabet, supposedly).
--- @return The given string with 'S' substituted by 's', '0' with 'o', etc.
function simplify_latin_ocr_result(s)
    return s:gsub('[I1]', 'l'):gsub('[O0]','o'):gsub('S','s'):gsub('C','c')
end

-------------------------------------------------------------------------------

--- Returns the hashtable of options and the array of remaining arguments.
--- Typical usage: opt,arg = getopt(arg)
--- @param arg The list of arguments, most likely "arg" provided by ocroscript
--- @return opt, arg where opt is the hashtable of options,
---         and arg is the list of non-option arguments.
function getopt(args)
    local opts = {}
    local remaining_args = {}
    i = 1
    -- I haven't used a for loop because at some point
    -- we can support "-key value" instead of "-key=value".
    while i <= #args do
        if args[i]:match('^-') then
            local option = args[i]
            option = option:gsub('^%-*','') -- trim leading `-' or `--'
            local key, val = option:match('^(.-)=(.*)$')
            if key and val then
                opts[key] = val
            else
                opts[option] = true
            end
        else
            table.insert(remaining_args, args[i])
        end
        i = i + 1
    end
    return opts, remaining_args
end

--- Read an image and abort if it's not there.
--- Any OCRopus-supported format should work;
--- that doesn't include TIFF at the moment (a2).
--- @param path The path to the image file.
--- @return The image (bytearray).
function read_image_gray_checked(path)
    local image = bytearray()
    if not pcall(function() read_image_gray(image, path) end) then
        print(("Unable to load image `%s'"):format(path))
        os.exit(1)
    end
    return image
end


--- Read a main file of a standard OCRopus dataset format
--- (a list of image and transcript filenames) and iterate over the filenames.
function dataset_filenames(path)
    return function(file)
        while true do
            local s = file:read("*l")
            if not s then
                return
            end
            local image_path, text_path = s:match("^([^%s]+)%s*([^%s]+)%s*$")
            if image_path and text_path then
                return combine_paths(path, image_path),
                       combine_paths(path, text_path)
            end
        end
    end, io.open(path, "r")
end

--- Iterate over (image, text) entries given a list of (image, text) filenames.
--- @param mode A flag: "color" means that images should be read in color.
function dataset_entries(path, mode)
    iterator, file = dataset_filenames(path)
    return function()
        local image_path, text_path = iterator(file)
        if not image_path then
            return
        else
            local image = bytearray()
            if not pcall(function()
                if mode == "color" then
                    read_png_rgb(image, image_path)
                else
                    read_image_gray(image, image_path)
                end
            end) then
                print(("Unable to load image: %s"):format(image_path))
                os.exit(1)
            end
            local transcript = read_transcript(text_path)
            return image, transcript
        end
    end
end

function log_dataset(logger, path, mode)
    for image, text in dataset_entries(path, mode) do
        logger:log("image", image)
        for i = 1, #text do
            logger:log(("char[%d]"):format(i), text[i])
        end
    end
end
