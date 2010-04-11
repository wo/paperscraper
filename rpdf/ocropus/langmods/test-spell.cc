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
// Project:
// File: 
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: 

#include "colib.h"
#include "langmod-aspell.h"
#include "langmod-ispell.h"
#include "langmod-shortest-path.h"
#include "langmod-openfst.h"
#undef CHECK
#undef TEST
#include "UnitTest++.h"

using namespace ocropus;
using namespace UnitTest;
using namespace colib;

struct SpellTest {
        autodel<ILanguageModel> langmod;

        void langmod_put(const char *s) {
            int n = strlen(s);
            langmod->start_chunk(n + 1);
            
            for (int i = 0; i < n; i++) {
                langmod->add_transition(i, i + 1, s[i], 1, i);
                //putchar(s[i]);
            }
            //printf("\n");
        }

        bool is_dictionary_word(const char *s) {
            //printf("=== is_dictionary_word ===\n");
            langmod_put(s);
            langmod->compute(1);
            
            if (!langmod->nresults()) {
                return false;
            }
            intarray result;
            floatarray costs;
            intarray ids;
            intarray states;
            //printf("=== start nbest :o ===\n");
            langmod->nbest(result, costs, ids, states, 0);
            //printf("=== end nbest :) ===\n");
            //printf("=== length of the best path: %d ===\n",result.length());
            //for(int i=0;i<result.length();i++) {
                //printf("result[%d]: %d ids[%d]: %d => best char: ",i,result[i],i,ids[i]);
                // putchar(result[i]);
                //printf("\n");
            //}
            return sum(costs) < 10 * costs.length();
        }

        bool correct_dictionary_words() {
            bool checker;
            checker = is_dictionary_word("open");
            //printf("=== open -> in dict: %d ===\n",int(checker));
            checker = (checker && is_dictionary_word("source"));
            //printf("=== source -> in dict: %d ===\n",int(checker));
            checker = (checker && is_dictionary_word("freedom"));
            //printf("=== freedom -> in dict: %d ===\n",int(checker));
            return checker;

        }

        bool wrong_dictionary_words() {
            return (is_dictionary_word("preved") ||
                    is_dictionary_word("medved") ||
                    is_dictionary_word("OCRopusRULEZ") );
        }

};
/*
TEST_FIXTURE(SpellTest, ShortestPathISpell) {
    langmod = make_IspellLanguageModel(make_ShortestPathLanguageModel());
    CHECK_CONDITION(correct_dictionary_words());
    CHECK_CONDITION(not wrong_dictionary_words());
}

TEST_FIXTURE(SpellTest, ShortestPathASpell) {
    langmod = make_AspellLanguageModel(make_ShortestPathLanguageModel());
    CHECK_CONDITION(correct_dictionary_words());
    CHECK_CONDITION(not wrong_dictionary_words());
}
*/
TEST_FIXTURE(SpellTest, OpenfstASpell) {
    langmod = make_AspellLanguageModel(make_OpenfstLanguageModel());
    CHECK_CONDITION(correct_dictionary_words());
    CHECK_CONDITION(not wrong_dictionary_words());
}

int main() {
    return RunAllTests();
}
