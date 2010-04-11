// Copyright 2006-2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz 
// or its licensors, as applicable.
// 
// You may not use this file except under the terms of the accompanying license.
// 
// Licensed under the Apache License, Version 2.0 (the "License"); you
// may not use this file except in compliance with the License. You may
// obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
// Project: langmods
// File: langmod-dict.cc
// Purpose: dictionary-based language model
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include <wctype.h>
#include <wchar.h>
#include <ctype.h>
#include "colib.h"
#include "langmod-dict.h"

using namespace colib;
using namespace ocropus;

namespace {
    
    int cmp(nustring &s1, nustring &s2) {
        int n = min(s1.length(), s2.length());
        for(int i = 0; i < n; i++) {
            if(s1[i].ord() < s2[i].ord()) return -1;
            if(s1[i].ord() > s2[i].ord()) return 1;
        }
        if(s1.length() < s2.length()) return -1;
        if(s1.length() > s2.length()) return 1;
        return 0;
    }
    bool operator < (nustring &s1, nustring &s2) 
        { return cmp(s1, s2) < 0; }
    bool operator ==(nustring &s1, nustring &s2) 
        { return cmp(s1, s2) == 0; }
    bool operator > (nustring &s1, nustring &s2) 
        { return cmp(s1, s2) > 0; }
    bool operator <=(nustring &s1, nustring &s2) 
        { return cmp(s1, s2) <= 0; }
    bool operator >=(nustring &s1, nustring &s2) 
        { return cmp(s1, s2) >= 0; }
    bool operator !=(nustring &s1, nustring &s2) 
        { return cmp(s1, s2) != 0; }

    void to_lower(nustring &to, nustring &from) {
        makelike(to, from);
        for(int i = 0; i < to.length(); i++) {
            to[i] = nuchar(towlower(from[i].ord()));
        }
    }

    struct WordList : IDict {
        narray<nustring> words;
        
        WordList(const char *path) {
            objlist<nustring> list;
            char buf[100];
            stdio file(path, "r");
            while(fscanf(file, "%99s", buf) == 1)
               list.push().utf8Decode(buf, strlen(buf));
            words.resize(list.length());
            for(int i = 0; i < words.length(); i++) {
                to_lower(words[i], list[i]);
                list[i].clear();
            }
            intarray permutation;
            quicksort(permutation, words);
            permute_move(words, permutation);
     
            for(int i = 0; i < words.length(); i++) {
                words[i].utf8Encode(buf, sizeof(buf));
                //printf("%s\n", buf);
            }
        }

        virtual bool lookup(nustring &correction,
                            nustring &word) {
            nustring t;
            to_lower(t, word);
            int l = 0;
            int r = words.length();
            while(r - l > 1) {
                int m = (l + r) / 2;
                int c = cmp(t, words[m]);
                if(c == 0) return true;
                if(c < 0)
                    r = m;
                else
                    l = m;
            }
            return t == words[l];
        }
    };

    bool word_continuation(int c) {
        return iswalpha(c) || c == '\'';
    }


    // This method is way too long; sorry.
    static void spellcheck(nustring &str,
                    floatarray &costs,
                    intarray &ids,
                    intarray &states,
                    IDict &dict,
                    float coef_good) {
        nustring new_classes;
        floatarray new_costs;
        intarray new_ids;
        intarray new_states;
        int word_start = 0;

        while(1) {
            // Move `word_start' to the start of the next word.
            while(word_start < str.length() && !iswalpha(str[word_start].ord())) {
                new_classes.push(str[word_start]);
                new_costs.push(costs[word_start]);
                new_ids.push(ids[word_start]);
                new_states.push(states[word_start]);
                word_start++;
            }

            if(word_start == str.length())
                break;

            int word_end = word_start;
            while(word_end < str.length() && word_continuation(str[word_end].ord())) {
                word_end++;
            }

            // not checking one-letter words
            if(word_end == word_start + 1) {
                new_classes.push(str[word_start]);
                new_costs.push(costs[word_start]);
                new_ids.push(ids[word_start]);
                new_states.push(states[word_start]);
                word_start++;
                continue;
            }

            // Now put the word into Aspell.
            nustring buf(word_end - word_start);
            for(int i = word_start; i < word_end; i++) 
                buf[i - word_start] = str[i];
            nustring correction;
            int correct = dict.lookup(correction, buf);

            if(correct) {
                // a good word - just copy to output arrays without problems
                for(int i = word_start; i < word_end; i++) {
                    new_classes.push(str[i]);
                    new_costs.push(costs[i] * coef_good);
                    new_ids.push(ids[i]);
                    new_states.push(states[i]);
                }
            } else {
                // It was a requirement that a language model
                // should always output something in the language.
                // Even in the case when the word is completely unrecognizable!
                if(correction.length() == 0) {
                    const char *foo = "foo";
                    correction.utf8Decode(foo, strlen(foo));
                }

                // We won't dive into questions,
                //     which letters were recognized bad and which were good.
                // Instead, we'll just give a huge cost to all the word,
                //     forbidding any adaptation on it.
                for(int i = 0; i < correction.length(); i++) {
                    new_classes.push(correction[i]);
                    new_costs.push(100);
                    new_ids.push(0);
                    new_states.push(-1);
                }
            }
            word_start = word_end;
        }

        move(str,    new_classes);
        move(costs,  new_costs);
        move(ids,    new_ids);
        move(states, new_states);
    }


    struct DictBestPath : IBestPath {
        autodel<IBestPath> bp;
        autodel<IDict> dict;

        virtual const char *description() {
            return "DictBestPath";
        }

        DictBestPath(IBestPath *b, IDict *d) : bp(b), dict(d) {}
        void bestpath(nustring &results,
                   floatarray &rcosts,
                   intarray &rids,
                   intarray &rstates) {
            bp->bestpath(results, rcosts, rids, rstates);
            spellcheck(results, rcosts, rids, rstates, *dict, 0.1);
        }

    };
}


namespace ocropus {
    IDict *make_WordList(const char *path) {
        return new WordList(path);
    }    
    IBestPath *make_DictBestPath(IBestPath *l, IDict *d) {
        return new DictBestPath(l, d);
    }
} 
