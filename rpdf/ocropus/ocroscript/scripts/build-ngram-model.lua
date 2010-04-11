n=2
boundary = "\1"
initial = 0.1

counts = {}
prefixes = {}

function add(ngram,inc)
   inc = inc or 1
   counts[ngram] = (counts[ngram] or 0) + inc
   prefix = ngram:sub(1,ngram:len()-1)
   prefixes[prefix] = (prefixes[prefix] or 0) + inc
end

function iterate_ngrams(n,chars,s,f)
   s = s or ""
   if n==0 then
      f(s)
   else
      for c in chars:gmatch(".") do
	 iterate_ngrams(n-1,chars,s..c,f)
      end
   end
end

print "adding background"

charset = boundary.."abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,.:;'\"`=-"
iterate_ngrams(n,charset,"", function (s) add(s,initial) end)

print "adding files"

for i,file in ipairs(arg) do
   for line in io.lines(file) do
      padded = (boundary:rep(n-1))..line..(boundary:rep(n-1))
      for k=1,line:len()+n-1 do
	 ngram = padded:sub(k,k+n-1)
	 add(ngram,0.5)
      end
   end
end

print "creating model"

model = openfst.make_NgramModel()


for ngram,c in pairs(counts) do
   prefix = ngram:sub(1,ngram:len()-1)
   p = prefixes[prefix]
   cost = -math.log(c/p)
   ok = pcall(function () model:addNgram(ngram,cost) end)
   if not ok then print("["..ngram.."]") end
end

print "writing model"

fst = model:take()
fst:Write("2gram.fst")
