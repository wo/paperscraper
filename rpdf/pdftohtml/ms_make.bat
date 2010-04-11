set CC=cl
set CFLAGS=/DWIN32 /I.. /I..\goo /I..\xpdf /O2 /nologo
set CXX=cl
set CXXFLAGS=%CFLAGS% /TP
set LIBPROG=lib

copy aconf-win32.h aconf.h

cd goo
%CXX% %CXXFLAGS% /c GHash.cc
%CXX% %CXXFLAGS% /c GList.cc
%CXX% %CXXFLAGS% /c GString.cc
%CXX% %CXXFLAGS% /c gmempp.cc
%CXX% %CXXFLAGS% /c gfile.cc
%CC% %CFLAGS% /c gmem.c
%CC% %CFLAGS% /c parseargs.c
%LIBPROG% /nologo /out:libGoo.lib GHash.obj GList.obj GString.obj gmempp.obj gfile.obj gmem.obj parseargs.obj

cd ..\xpdf
%CXX% %CXXFLAGS% /c Array.cc
%CXX% %CXXFLAGS% /c BuiltinFont.cc
%CXX% %CXXFLAGS% /c BuiltinFontTables.cc
%CXX% %CXXFLAGS% /c CMap.cc
%CXX% %CXXFLAGS% /c Catalog.cc
%CXX% %CXXFLAGS% /c CharCodeToUnicode.cc
%CXX% %CXXFLAGS% /c Decrypt.cc
%CXX% %CXXFLAGS% /c Dict.cc
%CXX% %CXXFLAGS% /c Error.cc
%CXX% %CXXFLAGS% /c FontEncodingTables.cc
%CXX% %CXXFLAGS% /c FontFile.cc
%CXX% %CXXFLAGS% /c Function.cc
%CXX% %CXXFLAGS% /c Gfx.cc
%CXX% %CXXFLAGS% /c GfxFont.cc
%CXX% %CXXFLAGS% /c GfxState.cc
%CXX% %CXXFLAGS% /c GlobalParams.cc
%CXX% %CXXFLAGS% /c ImageOutputDev.cc
%CXX% %CXXFLAGS% /c Lexer.cc
%CXX% %CXXFLAGS% /c JBIG2Stream.cc
%CXX% %CXXFLAGS% /c Link.cc
%CXX% %CXXFLAGS% /c Annot.cc
%CXX% %CXXFLAGS% /c PSTokenizer.cc
%CXX% %CXXFLAGS% /c NameToCharCode.cc
%CXX% %CXXFLAGS% /c Object.cc
%CXX% %CXXFLAGS% /c Outline.cc
%CXX% %CXXFLAGS% /c OutputDev.cc
%CXX% %CXXFLAGS% /c PDFDoc.cc
%CXX% %CXXFLAGS% /c PDFDocEncoding.cc
%CXX% %CXXFLAGS% /c PSOutputDev.cc
%CXX% %CXXFLAGS% /c Page.cc
%CXX% %CXXFLAGS% /c Parser.cc
%CXX% %CXXFLAGS% /c Stream.cc
%CXX% %CXXFLAGS% /c TextOutputDev.cc
%CXX% %CXXFLAGS% /c UnicodeMap.cc
%CXX% %CXXFLAGS% /c XRef.cc

%LIBPROG% /nologo /out:libxpdf.lib Array.obj JBIG2Stream.obj BuiltinFont.obj BuiltinFontTables.obj CMap.obj Catalog.obj CharCodeToUnicode.obj Decrypt.obj Dict.obj Error.obj FontEncodingTables.obj FontFile.obj Function.obj Gfx.obj GfxFont.obj GfxState.obj GlobalParams.obj ImageOutputDev.obj Lexer.obj Link.obj NameToCharCode.obj Object.obj OutputDev.obj Outline.obj PDFDocEncoding.obj PDFDoc.obj PSOutputDev.obj Page.obj Parser.obj Stream.obj TextOutputDev.obj UnicodeMap.obj XRef.obj Annot.obj PSTokenizer.obj 


cd ..\src
%CXX% %CXXFLAGS% /c HtmlFonts.cc
%CXX% %CXXFLAGS% /c HtmlLinks.cc
%CXX% %CXXFLAGS% /c HtmlOutPutDev.cc
%CXX% %CXXFLAGS% /c pdftohtml.cc

%CXX% /nologo /Fepdftohtml.exe HtmlFonts.obj HtmlLinks.obj HtmlOutputDev.obj  pdftohtml.obj ..\goo\libGoo.lib ..\xpdf\libxpdf.lib

cd ..
