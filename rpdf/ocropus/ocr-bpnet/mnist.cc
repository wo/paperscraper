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
// Project: ocr-utils
// File: mnist.cc
// Purpose: reading/writing datasets through IFeatureStream in MNIST format
// Responsible: mezhirov
// Reviewer:
// Primary Repository:
// Web Sites: www.iupr.org, www.dfki.de


#include <stdio.h>
#include "colib.h"
#include "mnist.h"
#include "ocr-utils.h"
#include "narray-io.h"

using namespace colib;
using namespace ocropus;

namespace {

    template<class T>
    void transpose_and_flip(narray<T> &a) {
        narray<T> t;
        t.resize(a.dim(1), a.dim(0));
        for (int x = 0; x < a.dim(0); x++) {
            for (int y = 0; y < a.dim(1); y++)
                t(y,a.dim(0) - x - 1) = a(x,y);
        }
        move(a, t);
    }

    template<class T>
    void flip_and_transpose(narray<T> &a) {
        narray<T> t;
        t.resize(a.dim(1), a.dim(0));
        for (int x = 0; x < a.dim(0); x++) {
            for (int y = 0; y < a.dim(1); y++)
                t(a.dim(1)-y-1,x) = a(x,y);
        }
        move(a, t);
    }


    enum {MAGIC_BYTES_IMAGES = 0x803,
          MAGIC_BYTES_LABELS = 0x801};

    struct Mnist : IFeatureStream {
        int count;
        int width;
        int height;
        int index;
        bool write_mode;
        stdio images;
        stdio labels;
        bytearray next_image;
        int next_label;

        // _________   generic (not specifically reading or writing)   ________

        Mnist(): count(0), index(0) {
        }

        virtual int nsamples() {
            return count;
        }

        void openFiles(const char *prefix, const char *mode, bool is_resource) {
            strbuf path;
            path.ensure(strlen(prefix) + 50);
            strcpy(path, prefix);
            strcat(path, "-images-idx3-ubyte");
            if(is_resource)
                images = open_resource(path);
            else
                images = fopen(path, mode);
            strcpy(path, prefix);
            strcat(path, "-labels-idx1-ubyte");
            if(is_resource)
                labels = open_resource(path);
            else
                labels = fopen(path, mode);
        }

        // _____________________________   reading   _____________________________

        void readNext() {
            next_image.resize(width, height);
            fread(next_image.data, width, height, images);
            transpose_and_flip(next_image);
            next_label = fgetc(labels);
        }

        virtual bool read(bytearray &result, int &label) {
            if (index >= count)
                return false;

            copy(result, next_image);
            label = next_label;
            index++;
            readNext();
            return true;
        }

        virtual bool read(floatarray &result, int &label) {
            bytearray tmp;
            if(!read(tmp, label))
                return false;
            copy(result, tmp);
            return true;
        }

        void readHeaders() {
            if(read_int32(images) != MAGIC_BYTES_IMAGES)
                throw "invalid magic bytes in the images file";
            if(read_int32(labels) != MAGIC_BYTES_LABELS)
                throw "invalid magic bytes in the labels file";

            count = read_int32(images);
            if(count != read_int32(labels))
                throw "the number of images and the number of labels mismatch";

            height = read_int32(images);
            width = read_int32(images);
        }

        void openRead(const char *prefix, bool search_in_path) {
            write_mode = false;
            openFiles(prefix, "rb", search_in_path);
            readHeaders();
            readNext();
        }

        /// __________________________   writing   _____________________________

        /// Write the number of samples into both headers.
        void fixHeaders() {
            ASSERT(write_mode);
            fseek(images, 4, SEEK_SET);
            write_int32(images, count);
            fseek(labels, 4, SEEK_SET);
            write_int32(labels, count);
        }

        ~Mnist() {
            if(write_mode)
                fixHeaders();
        }

        void writeHeaders() {
            write_int32(images, 0x803);
            write_int32(labels, 0x801);
            write_int32(images, 0); // number of samples (to be fixed later)
            write_int32(labels, 0);
            // Note: dimensions are only written with the first image
        }

        virtual void write(floatarray &array, int label) {
            ASSERT(write_mode);

            // We've promised to support 1D arrays in the interface.
            bool add_second_dimension  =  array.rank() == 1;
            if(add_second_dimension)
                array.reshape(array.dim(0), 1);

            ASSERT(array.rank() == 2);

            if(count == 0) {
                width = array.dim(0);
                height = array.dim(1);
                write_int32(images, height);
                write_int32(images, width);
            } else {
                if(width != array.dim(0) || height != array.dim(1))
                    throw "dimensions do not match";
            }

            copy(next_image, array);
            flip_and_transpose(next_image);
            fwrite(next_image.data, width, height, images);
            fputc(label, labels);
            count++;

            // restore the array to its original dimensions if needed
            if(add_second_dimension)
                array.reshape(array.dim(0));
        }

        void openWrite(const char *prefix) {
            write_mode = true;
            openFiles(prefix, "wb", false);
            writeHeaders();
        }
    };

    void read_all(bytearray &images, intarray &labels,
                  const char *path,
                  bool is_resource) {
        Mnist m;
        m.openRead(path, is_resource);
        int image_size = m.width * m.height;
        images.resize(m.count, image_size);
        labels.resize(m.count);
        for(int i = 0; i < m.count; i++) {
            m.next_image.reshape(image_size);
            rowcopy(images, i, m.next_image);
            labels[i] = m.next_label;
            if(i < m.count - 1)
                m.readNext();
        }
        images.reshape(m.count, m.width, m.height);
    }

}

namespace ocropus {

    IFeatureStream *make_MnistReader(const char *prefix, bool search_in_path) {
        Mnist *m = new Mnist();
        m->openRead(prefix, search_in_path);
        return m;
    }

    IFeatureStream *make_MnistWriter(const char *prefix) {
        Mnist *m = new Mnist();
        m->openWrite(prefix);
        return m;
    }

    void MNIST_60K(bytearray &images, intarray &labels) {
        read_all(images, labels, "mnist/train", true);
    }

    void MNIST_10K(bytearray &images, intarray &labels) {
        read_all(images, labels, "mnist/t10k", true);
    }
};
