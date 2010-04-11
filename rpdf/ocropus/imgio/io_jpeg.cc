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
// Project: ocropus
// File: didegrade.h
// Purpose: provide JPEG image I/O
// Responsible: mezhirov
// Reviewer: 
// Primary Repository: 
// Web Sites: www.iupr.org, www.dfki.de

#include <stdio.h>
extern "C" {
#include <jpeglib.h>
}
#include <string.h>
#include "io_jpeg.h"


using namespace colib;

namespace imgio {

// This code was adapted from an example to libjpeg.

void read_jpeg_any(bytearray &a, FILE *infile) {
    // This struct contains the JPEG decompression parameters and pointers to
    // working space (which is allocated as needed by the JPEG library).
    struct jpeg_decompress_struct cinfo;

    // We use our private extension JPEG error handler.
    // Note that this struct must live as long as the main JPEG parameter
    // struct, to avoid dangling-pointer problems.
    //struct my_error_mgr jerr;

    JSAMPARRAY buffer;                /* Output row buffer */
    int row_stride;                /* physical row width in output buffer */

    // In this example we want to open the input file before doing anything else,
    // so that the setjmp() error recovery below can assume the file is open.
    // VERY IMPORTANT: use "b" option to fopen() if you are on a machine that
    // requires it in order to read binary files. // gygygy, we don't do it anyway

    // Step 1: allocate and initialize JPEG decompression object

  struct jpeg_error_mgr jerr;
  memset(&jerr, 0, sizeof(jerr));
  cinfo.err = jpeg_std_error(&jerr);
  //if (setjmp(jerr.setjmp_buffer)) {
  //    /* If we get here, the JPEG code has signaled an error.
  //     * We need to clean up the JPEG object, close the input file, and return.
  //     */
  //    jpeg_destroy_decompress(&cinfo);
  //    throw "JPEG file error";
  //}
  // Now we can initialize the JPEG decompression object.
  jpeg_create_decompress(&cinfo);

  // Step 2: specify data source (eg, a file)

  jpeg_stdio_src(&cinfo, infile);

  // Step 3: read file parameters with jpeg_read_header()

  jpeg_read_header(&cinfo, TRUE);
  // We can ignore the return value from jpeg_read_header since
  //   (a) suspension is not possible with the stdio data source, and
  //   (b) we passed TRUE to reject a tables-only JPEG file as an error.
  // See libjpeg.doc for more info.
  //

  // Step 4: set parameters for decompression

  // In this example, we don't need to change any of the defaults set by
  // jpeg_read_header(), so we do nothing here.
  //

  // Step 5: Start decompressor

  (void) jpeg_start_decompress(&cinfo);
  // We can ignore the return value since suspension is not possible
  // with the stdio data source.
  //

  // We may need to do some setup of our own at this point before reading
  // the data.  After jpeg_start_decompress() we have the correct scaled
  // output image dimensions available, as well as the output colormap
  // if we asked for color quantization.
  // In this example, we need to make an output work buffer of the right size.
  // 


  // JSAMPLEs per row in output buffer
  row_stride = cinfo.output_width * cinfo.output_components;
    a.resize(row_stride, cinfo.output_height);
    
    // Make a one-row-high sample array that will go away when done with image
    buffer = (*cinfo.mem->alloc_sarray)
                ((j_common_ptr) &cinfo, JPOOL_IMAGE, row_stride, 1);

    // Step 6: while (scan lines remain to be read)
    //           jpeg_read_scanlines(...);

    // Here we use the library's state variable cinfo.output_scanline as the
    // loop counter, so that we don't have to keep track ourselves.
    //
    int y = cinfo.output_height - 1;
    while (cinfo.output_scanline < cinfo.output_height) {
        // jpeg_read_scanlines expects an array of pointers to scanlines.
        // Here the array is only one element long, but you could ask for
        // more than one scanline at a time if that's more convenient.
        //
        (void) jpeg_read_scanlines(&cinfo, buffer, 1);
        for(int i = 0; i < row_stride; i++)
            a(i,y) = buffer[0][i];
        y--;
    }
    if (cinfo.output_components) {
        a.reshape(cinfo.output_width, cinfo.output_components, cinfo.output_height);
    }

    // Step 7: Finish decompression

    jpeg_finish_decompress(&cinfo);
    // We can ignore the return value since suspension is not possible
    // with the stdio data source.

    // Step 8: Release JPEG decompression object

    jpeg_destroy_decompress(&cinfo);

    // At this point you may want to check to see whether any corrupt-data
    // warnings occurred (test whether jerr.pub.num_warnings is nonzero).
    //
}

// Used to read a colored version of the jpeg image

void read_jpeg_any(intarray &a, FILE *infile) {
    // This struct contains the JPEG decompression parameters and pointers to
    // working space (which is allocated as needed by the JPEG library).
    struct jpeg_decompress_struct cinfo;
//     cinfo.out_color_components = 3 ;

    // We use our private extension JPEG error handler.
    // Note that this struct must live as long as the main JPEG parameter
    // struct, to avoid dangling-pointer problems.
    //struct my_error_mgr jerr;

    JSAMPARRAY buffer;                /* Output row buffer */
    int row_stride;                /* physical row width in output buffer */

    // In this example we want to open the input file before doing anything else,
    // so that the setjmp() error recovery below can assume the file is open.
    // VERY IMPORTANT: use "b" option to fopen() if you are on a machine that
    // requires it in order to read binary files. // gygygy, we don't do it anyway

    // Step 1: allocate and initialize JPEG decompression object

    struct jpeg_error_mgr jerr;
    memset(&jerr, 0, sizeof(jerr));
    cinfo.err = jpeg_std_error(&jerr);
  //if (setjmp(jerr.setjmp_buffer)) {
  //    /* If we get here, the JPEG code has signaled an error.
  //     * We need to clean up the JPEG object, close the input file, and return.
    //     */
  //    jpeg_destroy_decompress(&cinfo);
  //    throw "JPEG file error";
  //}
  // Now we can initialize the JPEG decompression object.
    jpeg_create_decompress(&cinfo);

  // Step 2: specify data source (eg, a file)
    jpeg_stdio_src(&cinfo, infile); // does not set the attributes to any values, just initializes them
    
  // Step 3: read file parameters with jpeg_read_header()

    jpeg_read_header(&cinfo, TRUE); // sets the attributes values
  // We can ignore the return value from jpeg_read_header since
  //   (a) suspension is not possible with the stdio data source, and
  //   (b) we passed TRUE to reject a tables-only JPEG file as an error.
  // See libjpeg.doc for more info.
    //

  // Step 4: set parameters for decompression

  // In this example, we don't need to change any of the defaults set by
  // jpeg_read_header(), so we do nothing here.
    //

  // Step 5: Start decompressor
    
    // Output for debugging purposes only
/*    printf("Values of attributes of jpeg_decompress_struct: \n") ;
    printf("          image_width = \t%d\n", cinfo.image_width ) ;
    printf("          image_height = \t%d\n", cinfo.image_height ) ;
    printf("          num_components = \t%d\n", cinfo.num_components ) ;
    printf("          jpeg_color_space = \t%d\n", cinfo.jpeg_color_space ) ;
    printf("          out_color_space = \t%d\n", cinfo.out_color_space ) ;
    printf("          scale_num = \t%d\n", cinfo.scale_num ) ;
    printf("          scale_denom = \t%d\n", cinfo.scale_denom ) ;
    printf("          buffered_image = \t%d\n", cinfo.buffered_image ) ;
    printf("          raw_data_out = \t%d\n", cinfo.raw_data_out ) ;
    printf("          quantize_colors = \t%d\n", cinfo.quantize_colors ) ;
    printf("          desired_number_of_colors = \t%d\n", cinfo.desired_number_of_colors ) ;
    printf("          output_width = \t%d\n", cinfo.output_width ) ;
    printf("          output_height = \t%d\n", cinfo.output_height ) ;
    printf("          out_color_components = \t%d\n", cinfo.out_color_components ) ;
    printf("          output_components = \t%d\n", cinfo.output_components ) ;
    printf("          rec_outbuf_height = \t%d\n", cinfo.rec_outbuf_height ) ;
    printf("          actual_number_of_colors = \t%d\n", cinfo.actual_number_of_colors ) ;*/
    
    cinfo.out_color_space = JCS_RGB ; // set the output color space to RGB
    
    (void) jpeg_start_decompress(&cinfo);
  // We can ignore the return value since suspension is not possible
  // with the stdio data source.
    //

  // We may need to do some setup of our own at this point before reading
  // the data.  After jpeg_start_decompress() we have the correct scaled
  // output image dimensions available, as well as the output colormap
  // if we asked for color quantization.
  // In this example, we need to make an output work buffer of the right size.
    // 

    // Output for debugging purposes only
/*    printf("Values of attributes of jpeg_decompress_struct: \n") ;
    printf("          image_width = \t%d\n", cinfo.image_width ) ;
    printf("          image_height = \t%d\n", cinfo.image_height ) ;
    printf("          num_components = \t%d\n", cinfo.num_components ) ;
    printf("          jpeg_color_space = \t%d\n", cinfo.jpeg_color_space ) ;
    printf("          out_color_space = \t%d\n", cinfo.out_color_space ) ;
    printf("          scale_num = \t%d\n", cinfo.scale_num ) ;
    printf("          scale_denom = \t%d\n", cinfo.scale_denom ) ;
    printf("          buffered_image = \t%d\n", cinfo.buffered_image ) ;
    printf("          raw_data_out = \t%d\n", cinfo.raw_data_out ) ;
    printf("          quantize_colors = \t%d\n", cinfo.quantize_colors ) ;
    printf("          desired_number_of_colors = \t%d\n", cinfo.desired_number_of_colors ) ;
    printf("          output_width = \t%d\n", cinfo.output_width ) ;
    printf("          output_height = \t%d\n", cinfo.output_height ) ;
    printf("          out_color_components = \t%d\n", cinfo.out_color_components ) ;
    printf("          output_components = \t%d\n", cinfo.output_components ) ;
    printf("          rec_outbuf_height = \t%d\n", cinfo.rec_outbuf_height ) ;
    printf("          actual_number_of_colors = \t%d\n", cinfo.actual_number_of_colors ) ;*/

    
    

  // JSAMPLEs per row in output buffer
    row_stride = cinfo.output_width * cinfo.output_components;
    a.resize(cinfo.output_width, cinfo.output_height); // resize output array
    
    // Make a one-row-high sample array that will go away when done with image
    buffer = (*cinfo.mem->alloc_sarray)
            ((j_common_ptr) &cinfo, JPOOL_IMAGE, row_stride, 1);

    // Step 6: while (scan lines remain to be read)
    //           jpeg_read_scanlines(...);

    // Here we use the library's state variable cinfo.output_scanline as the
    // loop counter, so that we don't have to keep track ourselves.
    //
    int y = cinfo.output_height - 1;
    while (cinfo.output_scanline < cinfo.output_height) {
        // jpeg_read_scanlines expects an array of pointers to scanlines.
        // Here the array is only one element long, but you could ask for
        // more than one scanline at a time if that's more convenient.
        //
        (void) jpeg_read_scanlines(&cinfo, buffer, 1);
        int i = 0 ;
        while (i < row_stride) {
            int tmp = 0 ; // will contain the pixel value of the colored pixel
            tmp = buffer[0][i] ; // read R value
            tmp = tmp<<8 ;
            tmp = tmp + buffer[0][i+1] ; // read G value
            tmp = tmp<<8 ;
            tmp = tmp + buffer[0][i+2] ; // read B value
            a((int)(i/cinfo.output_components),y) = tmp ; // save value on correct pixel position
            i = i + 3 ;
        }
        y--;
    }

    // Step 7: Finish decompression

    jpeg_finish_decompress(&cinfo);
    // We can ignore the return value since suspension is not possible
    // with the stdio data source.

    // Step 8: Release JPEG decompression object

    jpeg_destroy_decompress(&cinfo);

    // At this point you may want to check to see whether any corrupt-data
    // warnings occurred (test whether jerr.pub.num_warnings is nonzero).
    //
}



void read_jpeg_gray(bytearray &a, FILE *f) {
    bytearray b;
    read_jpeg_any(b, f);
    if (b.rank() == 2) {
        move(a, b);
        return;
    }

    a.resize(b.dim(0), b.dim(2));
    for(int x = 0; x < b.dim(0); x++) for(int y = 0; y < b.dim(2); y++) {
        int s = 0;
        for(int k = 0; k < b.dim(1); k++)
            s += b(x,k,y);
        a(x,y) = s / b.dim(1);
    }
}


void read_jpeg_rgb(intarray &a, FILE *f) {
    intarray b;
    read_jpeg_any(b, f);
    if (b.rank() == 2) {
        move(a, b);
        return;
    }

    a.resize(b.dim(0), b.dim(2));
    for(int x = 0; x < b.dim(0); x++) for(int y = 0; y < b.dim(2); y++) {
        int s = 0;
        for(int k = 0; k < b.dim(1); k++)
            s += b(x,k,y);
        a(x,y) = s / b.dim(1);
    }
}



};
