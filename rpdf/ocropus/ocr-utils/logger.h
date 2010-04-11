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
// File: logger.h
// Purpose: 
// Responsible: 
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de, www.ocropus.org

/// \file logger.h
/// \brief The logging facility for debugging.

#ifndef h_logger_
#define h_logger_

#include "colib.h"

namespace ocropus {

    /// \brief The Logger class provides the centralized logging mechanism.
    /// 
    /// Just look at the example:
    /// \code
    /// #include "logger.h"
    ///
    /// Logger log_stuff("car.engine.debug");
    /// ...
    ///     log_stuff("ignition");
    /// ...
    ///     log_stuff("the front view", image);
    /// ...
    ///     log_stuff.format("ran %d km so far", km);
    /// ...
    /// \endcode
    /// 
    /// By default, all the loggers are disabled. Run the program like this
    /// to see the log:
    /// \code
    /// mkdir log
    /// ocrologdir=log ocrolog=car.engine <program>
    /// firefox log/index.html &
    /// \endcode
    /// 
    /// Note that enabling a logger X on the command line will also enable any
    /// loggers having the form X.Y, X.Y.Z etc.
    /// 
    /// To enable several loggers with the "ocrolog" variable,
    /// separate them with colons or semicolons.
    ///
    /// To enable messages related to the logging itself, enable the logger
    /// named "logger".
    ///
    /// Note: you can use logger.log() methods along with logger() operators.
    /// (This is the only way under Lua)
    class Logger {
        colib::strbuf name;
        void putIndent();        
        colib::stdio logImage(const char *description);
        colib::stdio logText(const char *description);

    public:
        bool enabled;

        /// \brief 
        /// Construct a logger with a given name
        /// and decide whether it's enabled or not.
        Logger(const char *name);

        /// A printf-like method.
        void format(const char *format, ...);

        /// Recolor a segmentation and log it.
        void recolor(const char *description, colib::intarray &);

        /// Just log the message.
        void operator()(const char *message);
        void log(const char *message){(*this)(message);}
        
        /// Log a boolean value.
        void operator()(const char *message, bool);
        void log(const char *message, bool value){(*this)(message, value);}
        
        /// Log an integer value.
        void operator()(const char *message, int);
        void log(const char *message, int value){(*this)(message, value);}
        
        /// Log a double value.
        void operator()(const char *message, double);
        void log(const char *message, double value){(*this)(message, value);}

        /// Log a string.
        void operator()(const char *description, const char *);
        void log(const char *message, const char *str){(*this)(message, str);}
        
        /// \brief Log a grayscale image.
        ///
        /// If the image is not 2-dimensional,
        /// it will be written as text
        /// (and the description text will become a link to it).
        void operator()(const char *description, colib::bytearray &);
        void log(const char *descr, colib::bytearray &a){(*this)(descr, a);}

        /// \brief Log a color image.
        ///
        /// If the image is not 2-dimensional,
        /// it will be written as text.
        void operator()(const char *description, colib::intarray &);
        void log(const char *descr, colib::intarray &a){(*this)(descr, a);}

        /// \brief Log an array of floats.
        void operator()(const char *description, colib::floatarray &);
        void log(const char *descr, colib::floatarray &a){(*this)(descr, a);}

        /// Log a nuchar value.
        void operator()(const char *description, colib::nuchar);
        void log(const char *descr, colib::nuchar c){(*this)(descr, c);}
        
        /// Log a nustring value, decoding it to UTF-8.
        void operator()(const char *description, colib::nustring &);
        void log(const char *descr, colib::nustring &s){(*this)(descr, s);}

        /// Log a rectangle.
        void operator()(const char *description, colib::rectangle &);
        void log(const char *descr, colib::rectangle &r){(*this)(descr, r);}

        /// Log the value of a pointer (not quite useful).
        void operator()(const char *description, void *);
        void log(const char *descr, void *ptr){(*this)(descr, ptr);}

        /// Draw 4 lines on the line image and log it.
        void operator()(const char *description, colib::bytearray &line_image,
             int baseline_y, int xheight_y, int ascender_y, int descender_y);
        void log(const char *descr, colib::bytearray &line_image,
             int baseline_y, int xheight_y, int ascender_y, int descender_y) {
            (*this)(descr, line_image,
                    baseline_y, xheight_y, ascender_y, descender_y);
        }
    
        /// Get a bestpath() and log it.
        void operator()(const char *description, colib::IGenericFst &l);
        void log(const char *descr, colib::IGenericFst &L){(*this)(descr, L);}
    
        /// Increase indentation level in the log.
        void indent();
        
        /// Decrease indentation level in the log.
        void dedent();
    };
    
    /// Switch the logger directory. All the logs will continue to the new file.
    void set_logger_directory(const char *);
};

#endif
