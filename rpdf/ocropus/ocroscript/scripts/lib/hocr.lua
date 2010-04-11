-- Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
-- or its licensors, as applicable.
-- 
-- You may not use this file except under the terms of the accompanying license.
-- 
-- Licensed under the Apache License, Version 2.0 (the "License"); you
-- may not use this file except in compliance with the License. You may
-- obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Project: ocroscript
-- File: hocr.lua
-- Purpose: hOCR output
-- Responsible: mezhirov
-- Reviewer: 
-- Primary Repository: 
-- Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

-------------------------------------------------------------------------------

local function imitate_class(class, base)
    class.__base__ = base

    class.new = function(self, ...)
        local object = {}
        self:__init__(object, ...)
        return object
    end
    
    class.__init__ = function(class, object, ...)
        if class.__base__ then
            class.__base__:__init__(object, ...)
        end
        for key, value in pairs(class) do
            object[key] = value
        end
        if object.create then
            object:create(...)
        end
    end

    setmetatable(class,{__call = class.new}) -- make C() be the same as C:new()
end

-------------------------------------------------------------------------------

local function output_hOCR_meta(header, meta, default)
    local t = header[meta]
    if not t then
        t = default
    end
    print(string.format('        <meta name="ocr-%s" content="%s" />', meta, t))
end

local function output_hOCR_title(header, default)
    local t = header.title
    if not t then
        t = default
    end
    print(string.format('        <title>%s</title>', t))
end

local function output_hOCR_char(c --[[integer]])
    if c == string.byte('&') then
        io.write('&amp;')
    elseif c == string.byte('<') then
        io.write('&lt;')
    elseif c == string.byte('>') then
        io.write('&gt;')
    elseif c > 127 then
        io.write(string.format('&#%d;', c))
    else
        io.write(string.char(c))
    end
end

-------------------------------------------------------------------------------

TreeNode = {}

function TreeNode:append(node)
    table.insert(self, node)
end

imitate_class(TreeNode)

-------------------------------------------------------------------------------

DocumentNode = {}

function DocumentNode:hocr_output()
    local header = self.header or {}
    print '<!DOCTYPE html'
    print '  PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"'
    print '   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'
    print '<html xmlns="http://www.w3.org/1999/xhtml">'
    print '    <head>'
    --output_hOCR_meta(header, 'system', 'OCRopus' .. get_version_string())
    output_hOCR_meta(header, 'capabilities', 'ocr_line ocr_page')
    output_hOCR_meta(header, 'langs', 'en')
    output_hOCR_meta(header, 'scripts', 'Latn')
    output_hOCR_meta(header, 'microformats', '')
    output_hOCR_title(header, 'OCR Output')
    print "    </head>"
    print "<body>"
    for i = 1, #self do
        self[i]:hocr_output(self)
    end
    print "</body>"
    print "</html>"
end

imitate_class(DocumentNode, TreeNode)

-------------------------------------------------------------------------------

-- Fields:
--  description
--  width
--  height
--  paragraphs
--  headings
--  time_report

PageNode = {}

function PageNode:hocr_output(document --[[unused, but might be used later]])
    if self.width and self.height then
        print(string.format(
           '<div class="ocr_page" title="image %s; bbox 0 0 %d %d">',
           self.description,
           self.width,
           self.height))
    else
        print(string.format('<div class="ocr_page" title="image %s">',
              self.description))
    end

    local paragraphs = self.paragraphs
    if not paragraphs then paragraphs = {} end
    local headings = self.headings
    if not headings then headings = {} end

    local paragraph = false
    for line=1, #self do
        if paragraphs[line] --[[formerly: page:isParagraph(line)]] then
            if paragraph then
                print '</p>'
            end
            print('<p class="ocr_par">')
            paragraph = true
        end
        local text = nustring()
        if not headings[line] then
            self[line]:hocr_output(self)
        else 
            if paragraph then
                print '</p>'
            end
            if line == 1 or not headings[line - 1] then
                print '<h3>'
            end
            self[line]:hocr_output(self)
            if line == #self or not headings[line + 1] then
                print '</h3>'
            end
            paragraph = false
        end
    end
    if paragraph then
        -- close final paragraph --
        print '</p>'
    end
    if self.time_report then
        print(string.format('<!-- %s -->', self.time_report))
    end
    print '</div>'
end   

imitate_class(PageNode, TreeNode)

-------------------------------------------------------------------------------

LineNode = {}

function LineNode:create(bbox, text)
    self.bbox = bbox
    self.text = text
end

function LineNode:hocr_output(page)
    local line = self.text
    local bbox = self.bbox
    if not line or line:length() == 0 then
        return
    end
    local bbox_string = ''
    if page and bbox then
        bbox_string = string.format(' title="bbox %d %d %d %d"',
                       bbox.x0,                -- left
                       page.height - bbox.y1,  -- top
                       bbox.x1,                -- right
                       page.height - bbox.y0)  -- bottom
    end
    io.write(string.format('<span class="ocr_line"%s>', bbox_string))
   
    for i = 0, line:length() - 2 do
        output_hOCR_char(line:at(i):ord())
    end 
    if remove_hyphens 
        and line:length() > 0 
        and line.at(line:length() - 1).ord() == string.byte('-')
    then
        io.write '</span>'
    else 
        if line:length() > 0 then
            output_hOCR_char(line:at(line:length()-1):ord())
        end
        print '</span>'
    end
end

imitate_class(LineNode, TreeNode)
