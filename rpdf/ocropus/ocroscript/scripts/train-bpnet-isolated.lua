-- Copyright 2006-2008 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
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
-- File: train-bpnet.lua
-- Purpose: training a backpropagation net on isolated characters
-- Responsible: mezhirov
-- Reviewer: 
-- Primary Repository: 
-- Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

require 'lib.util'

opt,arg = getopt(arg)

if #arg ~= 2 then
    print ('Usage: ocroscript '..arg[0]..' [options] <dataset> <output>')
    print '     <dataset> - a list of "image_path text_path" lines'
    print 'Isolated training: every line should contain one character only'
    print 'Options:'
    print '     --nhidden=...       - the number of hidden units'
    print '     --epochs=...        - the number of epochs to train'
    print '     --learningrate=...  - weights change coefficient'
    print '     --testportion=...   - how much data to leave for validation'
    print '     --normalize=...     - normalize means and dispersions of input'
    print '     --shuffle=...       - randomize the order of data'
    print '     --degrade=...       - the number of passes with degradation'
    print '                           (set to 0 to make one pass on pure data)'
    os.exit(1)
end

dataset_path = arg[1]
result_path = arg[2]

repetitions = opt.degrade or 50

-- make the bpnet to train
c = make_BpnetClassifier()
c:param("nhidden", opt.nhidden or 300)
c:param("epochs", opt.epochs or 10)
c:param("learningrate", opt.learningrate or .2)
c:param("testportion", opt.testportion or .1)
c:param("normalize", opt.normalize or 1)
c:param("shuffle", opt.shuffle or 1)


-- load the alphabet
train_data = {}
for image, text in dataset_entries(dataset_path) do
    assert(#text == 1) -- transcript is actually an array of nustrings
    text = text[1] -- but there should be only one item in the array
    table.insert(train_data, {image = image, text = text})
end

-- now train on degraded data
cc = make_AdaptClassifier(c)
cc:startTraining()

if repetitions > 0 then
    max_k = repetitions
else
    max_k = 1
end

for k = 1, max_k do
    for key, i in pairs(train_data) do
        local image = bytearray:new()
        narray.copy(image, i.image)
        if repetitions > 0 then
            degrade(image)
        end
        cc:addTrainingChar(image, i.text)
        image:delete() -- that's not to push on the garbage collector too much
    end
    print(string.format("feature extraction: %d of %d", k, repetitions))
end
print "Start training"
cc:finishTraining()
cc:save(result_path)
