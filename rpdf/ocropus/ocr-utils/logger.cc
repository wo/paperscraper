// Copyright 2007 Deutsches Forschungszentrum fuer Kuenstliche Intelligenz
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
// File: logging.cc
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

#include <stdarg.h>
#include "colib.h"
#include "imgio.h"
#include "narray-io.h"
#include "logger.h"
#include "imglib.h"
#include "ocr-utils.h"
#include "sysutil.h"


using namespace colib;
using namespace imgio;
using namespace imglib;
using namespace ocropus;


namespace {
    narray<strbuf> enabled_logs;
    int indent_level = 0;
    int image_counter = 0;
    bool self_logging;

    strbuf dir;
    strbuf html;
    stdio file;
    
    /// Returns true if the given specification chunk turns on a log with the given name.
    /// The simplest way would be to use !strcmp, but we have an extension:
    /// a spec "X" would turn on a log named "X.Y".
    bool turns_on(const char *spec, const char *name) {
        int spec_len = strlen(spec);
        int name_len = strlen(spec);
        if(spec_len > name_len)
            return false; // then spec is too long to be a prefix of name
        if(strncmp(spec, name, spec_len))
            return false; // then spec can't be a prefix of name
        if(name_len == spec_len)
            return true; // spec == name
        return name[spec_len] == '.';
    }
    
    bool turned_on(const char *name) {
        for(int i = 0; i < enabled_logs.length(); i++)
            if(turns_on(enabled_logs[i], name))
                return true;
        return false;                
    }

    void init_logging() {
        char *ocrolog = getenv("ocrolog");
        if(!ocrolog)
            return;
        split_string(enabled_logs, ocrolog, ":;");
        self_logging = turned_on("logger");
    }


    void start_logging() {
        if(!!file)
            return;
        const char *ocrologdir = getenv("ocrologdir");
        if(!ocrologdir) {
            ocrologdir = "log.ocropus";
        }
        set_logger_directory(ocrologdir);
        
        fprintf(file, "logging turned on for the following loggers:<BR /><UL>\n");
        for(int i = 0; i < enabled_logs.length(); i++)
            fprintf(file, "    <LI>%s</LI>\n", (char *) enabled_logs[i]);
        fprintf(file, "</UL>\n");
        fflush(file);
    }

    void draw_line(intarray &a, int y, int color) {
        if(y < 0 || y >= a.dim(1)) return;
        for(int x = 0; x < a.dim(0); x++)
            a(x, y) = color;
    }

};


namespace ocropus { 
    void Logger::putIndent() {
        fprintf(file, "[%s] ", (char *) name);
        for(int i = 0; i < indent_level; i++) {
            fprintf(file, "&nbsp;&nbsp;");
        }
    }
    
    stdio Logger::logImage(const char *description) {
        char buf[strlen(dir) + 100];
        sprintf(buf, "%s/ocropus-log-%d.png", (char *) dir, image_counter);
        putIndent();
        fprintf(file, "%s: <IMG SRC=\"ocropus-log-%d.png\"><BR>\n",
                description, image_counter);
        fflush(file);
        image_counter++;
        return stdio(buf, "wb");
    }
    
    stdio Logger::logText(const char *description) {
        char buf[strlen(dir) + 100];
        sprintf(buf, "%s/ocropus-log-%d.txt", (char *) dir, image_counter);
        putIndent();
        fprintf(file, "<A HREF=\"ocropus-log-%d.txt\">%s</A><BR>\n",
                image_counter, description);
        fflush(file);
        image_counter++;
        return stdio(buf, "w");
    }



    Logger::Logger(const char *name) {
        this->name = name;

        if(!enabled_logs.length()) {
            init_logging();
        }

        enabled = false;
        for(int i = 0; i < enabled_logs.length(); i++) {
            if(turns_on(enabled_logs[i], name)) {
                enabled = true;
                break;
            }
        }

        if(enabled || self_logging)
            start_logging();
        
        // trying to handle gracefully the situation when the log file couldn't be opened
        if(!file) {
            enabled = false;
            return;
        }

        if(self_logging)
            fprintf(file, "[logger] `%s': %s<BR />\n", (char *) name, enabled ? "enabled": "disabled");            
    }
    
    void Logger::format(const char *format, ...) {
        if(!enabled) return;
        va_list va;
        va_start(va, format);
        putIndent();
        vfprintf(file, format, va);
        fprintf(file, "<BR />\n");
        va_end(va);
        fflush(file);
    }
    
    void Logger::operator()(const char *s) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s<BR />\n", s);
        fflush(file);
    }
    void Logger::operator()(const char *message, bool val) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s: %s<BR>\n", message, val ? "true" : "false");
        fflush(file);
    }
    void Logger::operator()(const char *message, int val) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s: %d<BR>\n", message, val);
        fflush(file);
    }
    void Logger::operator()(const char *message, double val) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s: %lf<BR>\n", message, val);
        fflush(file);
    }
    void Logger::operator()(const char *message, const char *val) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s: \"%s\"<BR>\n", message, val);
        fflush(file);
    }
    void Logger::operator()(const char *message, nuchar val) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s: \'%lc\' (hex %x, dec %x)<BR>\n",
                message, val.ord(), val.ord(), val.ord());
        fflush(file);
    }
    void Logger::operator()(const char *description, colib::intarray &a) {
        if(!enabled) return;
        if(a.rank() == 2) {
            stdio f = logImage(description);
            write_png_rgb(f, a);
        } else {
            stdio f = logText(description);
            text_write(f, a);
        }
    }
    void Logger::recolor(const char *description, colib::intarray &a) {
        if(!enabled) return;
        if(a.rank() == 2) {
            stdio f = logImage(description);
            intarray tmp;
            copy(tmp, a);
            simple_recolor(tmp);
            write_png_rgb(f, tmp);
        } else {
            stdio f = logText(description);
            text_write(f, a);
        }
    }
    void Logger::operator()(const char *description, colib::bytearray &a) {
        if(!enabled) return;
        if(a.rank() == 2) {
            stdio f = logImage(description);
            write_png(f, a);
        } else {
            stdio f = logText(description);
            text_write(f, a);
        }
    }
    void Logger::operator()(const char *description, colib::floatarray &a) {
        if(!enabled) return;
        stdio f = logText(description);
        text_write(f, a);
    }
    void Logger::operator()(const char *message, colib::nustring &val) {
        if(!enabled) return;
        char *buf = val.newUtf8Encode();
        putIndent();
        fprintf(file, "%s: nustring(\"%s\")<BR>\n", message, buf);
        fflush(file);
        delete[] buf;
    }
    void Logger::operator()(const char *description, colib::rectangle &val) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s: rectangle(%d,%d,%d,%d)<BR>\n",
                description, val.x0, val.y0, val.x1, val.y1);
        fflush(file);
    }
    
    void Logger::operator()(const char *message, colib::IGenericFst &val) {
        if(!enabled) return;
        nustring s;
        val.bestpath(s);
        char *buf = s.newUtf8Encode();
        putIndent();
        fprintf(file, "%s: ICharLattice(bestpath: \"%s\")<BR>\n", message, buf);
        fflush(file);
        delete[] buf;
    }

    
    void Logger::operator()(const char *description, void *ptr) {
        if(!enabled) return;
        putIndent();
        fprintf(file, "%s: pointer(%p)<BR>\n", description, ptr);
        fflush(file);
    }

    void Logger::indent() {
        if(enabled)
            indent_level++;
    }
    void Logger::dedent() {
        if(enabled)
            indent_level--;
    }
    void Logger::operator()(const char *description, bytearray &line_image,
             int baseline, int xheight, int ascender, int descender) {
        if(!enabled) return;
        intarray a;
        copy(a, line_image);
        draw_line(a, baseline, 0xFF0000);
        draw_line(a, xheight, 0xFF7700);
        draw_line(a, ascender, 0x77FF00);
        draw_line(a, descender, 0x00FF00);
        (*this)(description, a);
    }

    void set_logger_directory(const char *path) {
        if(!!file) {
            fprintf(file, "log finished; switching to directory %s\n", path);
        }
        mkdir_if_necessary(path);
        strbuf old_dir;
        if(dir)
            old_dir = dir;
        dir = path;
        html = path;
        html += "/index.html";
        file = fopen(html,"w");
        if(!file) {
            fprintf(stderr, "unable to open log file `%s' for writing\n", 
                    (char *) html);
        }
        fprintf(file, "<HTML><BODY>\n");
        if(old_dir) {
            fprintf(file, "Log continued from %s<P>\n", (char *) old_dir);
        }
    }

}
