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
-- File: paragraphs.lua
-- Purpose: detecting paragraphs
-- Responsible: mezhirov
-- Reviewer: 
-- Primary Repository: 
-- Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

--- Detect paragraphs in the text
--- and return a Lua array with `true' corresponding to paragraph starters.
--- @param regions A RegionExtractor set to line regions.
--- @return A Lua table (numbered from 1, as the regions) of booleans.
function detect_paragraphs(regions)
    local result = {}
    for i = 1, regions:length() - 2 do
        local rect = regions:bbox(i)
        local next = regions:bbox(i + 1)
        -- A line is a paragraph starter if, compared to the next line:
        -- it's above
        -- its right edge is more or less the same
        -- its left edge is shifted to the right
        result[i+1] = next.y0 < rect.y0
                  and math.abs(next.x1 - rect.x1) < 0.5 * rect:height()
                  and rect.x0 - next.x0 > 0.5 * rect:height()
    end
    -- The last line is never a paragraph starter.
    if regions:length() > 1 then
        result[regions:length()] = false
    end
    return result
end
