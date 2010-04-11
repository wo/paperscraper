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
// Project: ocr-adaptive
// File: langmod-aspell.cc
// Purpose: trivial WFST implementation that calls aspell
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include <ctype.h>
#include "colib.h"
#include "imgio.h"
#include "imglib.h"
extern "C" {
#include <aspell.h>
}
#include "langmod-dict.h"
#include "langmod-aspell.h"

using namespace ocropus;
using namespace colib;

/// This language model is a wrapper for another language model.
/// In the building phase, it's completely transparent;
/// when it produces the resulting string and costs,
/// it checks all words with ISpell and changes the cost of unrecognized words to 100.
/// Also the unrecognized words are replaced with some guess that is in the dictionary
/// (whether the guess is reasonable or not).

struct AspellDict : IDict {
    AspellSpeller *spell_checker;
    
    AspellDict() {
        AspellConfig *spell_config = new_aspell_config();
        aspell_config_replace(spell_config, "lang", "en_US");
        AspellCanHaveError *possible_err = new_aspell_speller(spell_config);
        delete_aspell_config(spell_config);
        spell_checker = NULL;
        if (aspell_error(possible_err))
            throw aspell_error_message(possible_err);
        else
            spell_checker = to_aspell_speller(possible_err);
    }
    
    ~AspellDict() {
         delete_aspell_speller(spell_checker);
    }

    virtual bool lookup(colib::nustring &correction,
                        colib::nustring &word) {
        narray<char> word_encoded;
        word.utf8Encode(word_encoded);
        int is_correct = aspell_speller_check(spell_checker,
                            &word_encoded[0], word_encoded.length());

        if(is_correct)
            return true;

        // a bad word: we want to get a possible correction
        const AspellWordList *suggestions = aspell_speller_suggest(spell_checker, &word_encoded[0], word_encoded.length());
        AspellStringEnumeration *aspell_elements = aspell_word_list_elements(suggestions);
        const char *corrected_word = aspell_string_enumeration_next(aspell_elements);
        if(corrected_word)
            correction.utf8Decode(corrected_word, strlen(corrected_word));
        delete_aspell_string_enumeration(aspell_elements);        
        return false;
    }
};

namespace ocropus {
    IDict *make_Aspell() {
        return new AspellDict();
    }
};
