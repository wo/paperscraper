DIE() {
    echo "ERROR: $*" 1>&2
    exit 1
}
AC_INIT(ocropus, 0.2)
AC_CONFIG_SRCDIR(ocrocmd/ocrocmd.cc)

AC_LANG_CPLUSPLUS

tesseract_prefix=/usr/local
AC_ARG_WITH(tesseract,
[
  --with-tesseract=...    path to tesseract if not installed in /usr/local/.
                          Should be the same directory as was given to
                          tesseract's configure script through --prefix=],
tesseract_prefix=$withval)

AC_ARG_VAR(tessheaders, Location of Tesseract's headers)
AC_ARG_VAR(tesslibs, Location of Tesseract's libraries)

if [[ x$tessheaders = x ]]; then
    tessheaders=$tesseract_prefix/include/tesseract
else
    AC_CHECK_FILE($tessheaders/baseapi.h,,
        AC_MSG_ERROR([please install Tesseract and make sure headers are in $tessheaders]))
fi
if [[ x$tesslibs = x ]]; then
    tesslibs=$tesseract_prefix/lib
fi

AC_PROG_CXX
AC_PROG_CC
AC_PROG_RANLIB

AC_HEADER_STDC
AC_HEADER_SYS_WAIT
AC_CHECK_HEADERS([float.h malloc.h stdint.h stdlib.h string.h unistd.h wchar.h])

# verify we are on a POSIX system
AC_CHECK_HEADER(unistd.h,,AC_SUBST(noposix, 1))

# --- libz (required) ---
AC_CHECK_LIB(z, compress,,
    AC_MSG_ERROR([no zlib; please install zlib or equivalent]))

# --- libpng (required) ---
AC_CHECK_HEADER(png.h,,
    AC_MSG_ERROR([no png.h; please install libpng12-dev or equivalent]))
AC_CHECK_LIB(png, png_sig_cmp,,
    AC_MSG_ERROR([no png_sig_cmp; please install libpng12-dev or equivalent]))

# --- libjpg (required) ---
AC_CHECK_HEADER(jpeglib.h,,
    AC_MSG_ERROR([no jpeglib.h; please install libjpeg62-dev or equivalent]))
AC_CHECK_LIB(jpeg, jpeg_std_error,,
    AC_MSG_ERROR([no jpeglib.h; please install libjpeg62-dev or equivalent]))

# --- libtiff (required) ---
AC_CHECK_LIB(tiff, TIFFOpen,,
    AC_MSG_ERROR([no TIFFOpen; please install libtiff4-dev or equivalent]))

# --- libpthread (needed by tesseract) ---
AC_CHECK_LIB(pthread, pthread_create,,)

# --- libtesseract (optional) ---
# NB: we can only use functions with C linkage here
AC_CHECK_LIB(tesseract_full, err_exit,, AC_SUBST(notesseract,1))

# --- openFST (optional but recommended) ---
AC_ARG_WITH(fst,[  --without-fst           disable openFST language modelling],
    [ac_cv_use_fst=$withval], [ac_cv_use_fst=yes])
if test x$ac_cv_use_fst != xno; then
    AC_CHECK_LIB(pthread, pthread_create,,AC_SUBST(nofst,1))
    AC_CHECK_HEADER(fst/lib/fst.h,,AC_SUBST(nofst, 1))
    AC_CHECK_LIB(fst, main,,AC_SUBST(nofst, 1))
else
    AC_SUBST(nofst, 1)
fi

# --- aspell (optional) ---
AC_ARG_WITH(aspell,[  --without-aspell        disable aspell as dictionary],
    [ac_cv_use_aspell=$withval], [ac_cv_use_aspell=yes])
if test x$ac_cv_use_aspell != xno; then
    AC_CHECK_HEADER(aspell.h,,AC_SUBST(noaspell, 1))
    AC_CHECK_LIB(aspell, new_aspell_config,,AC_SUBST(noaspell, 1))
else
    AC_SUBST(noaspell, 1)
fi

# --- lua / ocroscript (optional but recommended) ---
AC_ARG_WITH(ocroscript,[  --without-ocroscript    disable ocroscript (ocropus lua interpreter)],
    [ac_cv_use_lua=$withval], [ac_cv_use_lua=yes])
if test x$ac_cv_use_lua == xno; then
    AC_SUBST(nolua, 1)
#else
    # do we need to check sth here? lua and tolua now ship with ocropus
fi

# --- libedit (optional for ocroscript interactive mode) ---
AC_CHECK_LIB(edit,readline,,AC_SUBST(noeditline,1))

# --- SDL (optional for graphical debugging in ocroscript) ---
AC_ARG_WITH(SDL,[  --without-SDL           disable SDL (graphical debugging for ocroscript)],
    [ac_cv_use_sdl=$withval], [ac_cv_use_sdl=yes])
if test x$ac_cv_use_sdl != xno; then
    AC_CHECK_LIB(SDL,SDL_Init,,AC_SUBST(nosdl,1))
    AC_CHECK_LIB(SDL_gfx,rotozoomSurface,,AC_SUBST(nosdl,1))
else
    AC_SUBST(nosdl, 1)
fi

# --- leptonica (optional) ---
AC_ARG_WITH(leptonica,[  --with-leptonica        enable use of Leptonica],
    AC_CHECK_LIB(lept,pixCreate,,AC_SUBST(nolept,1)),
    AC_SUBST(nolept,1))


AC_TYPE_INT64_T
AC_TYPE_PID_T

AC_FUNC_FORK
AC_CHECK_FUNCS([dup2 memset sqrt strchr strdup strrchr])

AC_CONFIG_FILES([Jamrules])
AC_OUTPUT

echo
echo "OK! Now you can build OCRopus by typing \"jam\"."
echo "If compilation will be successful, you should..."
echo "    cd ocroscript"
echo "    ./run-tests"
echo "    ./run-bigtests"
