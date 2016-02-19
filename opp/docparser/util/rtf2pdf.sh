#!/bin/sh

########################################################################
#
#  Convert an rtf document to pdf format using 'Ted' and 'GhostScript'.
#
#  Usage	rtf2pdf.sh --paper paper something.rtf something.pdf
#  Or		rtf2pdf.sh something.rtf something.pdf
#
#  Valid values for paper are a4, a5, a6, letter, legal and executive
#
#  This is an example. Refer to http://www.nllgg.nl/Ted/index.html for the
#  'Ted' documentation.
#
#  If you want 'Ted' to set configurable resources, use
#  Ted  --printToFilePaper --setProperty ... in the Ted way. E.G:
#  Ted  --setProperty usePostScriptFilters 1 \
#	--setProperty usePostScriptIndexedImages 1  \
#	--setProperty afmDirectory /usr/share/ghostscript/fonts  \
#	--setProperty fontDirectory /usr/share/ghostscript/fonts  \
#	--setProperty ghostscriptFontmap \
#				/usr/share/ghostscript/6.53/lib/Fontmap \
#	--setProperty ghostscriptFontToXmapping \
#				/usr/share/ghostscript/6.53/lib/fonts.dir \
#	--printToFilePaper .....
#  This has the advantage over the ++printToFilePaper call and X11 
#  resource settings with -xrm Ted.usePostScriptFilters:1 style arguments 
#  that it does not require an X11 server.
#  The settings can also be stored in /etc/Ted.properties or in 
#  $(HOME)/.Ted.properies files. Refer to the Ted documentation for 
#  more details.
#
#  The file /usr/share/ghostscript/version/doc/Ps2pdf.htm documents 
#  many settings for ghostscript that influence the generation of pdf.
#  The actual meaning of the parameters is explained in Adobe technical 
#  note #5151: "Acobat Distiller Parameters". With some effort, note #5151 
#  can be found using the search facility on www.adobe.com.
#
#  To disable jpeg compression of 8 bit per component images:
#      -dAutoFilterColorImages=false -dEncodeColorImages=false
#  or
#      -dAutoFilterColorImages=false -sColorImageFilter=FlateEncode
#  to enable: (default)
#      -dAutoFilterColorImages=true
#
#  To produce uncompressed pdf:
#      -dCompressPages=false
#  To produce compressed pdf: (default)
#      -dCompressPages=true
#
#  Depending on your temper, you could also have a look at the pdfopt script
#
########################################################################

PAPER=

case $# in
    2)
	;;
    4)
	case $1 in
	    --paper)
		;;
	    *)
		echo $0: '$1='$1 'Expected --paper'
		exit 1
		;;
	esac

	case $2 in
	    a4|a5|a6|letter|legal|executive)
		PAPER=$2
		;;
	    *)
		echo $0: '$2='$2 'Expected a4|a5|a6|letter|legal|executive'
		exit 1
		;;
	esac
	shift; shift;
	;;
    *)
	echo $0: '$#='$#
	exit 1
	;;
esac

case $PAPER in
    ?*)
	Ted --printToFilePaper "$1" /tmp/$$.ps $PAPER

	gs -q	-dNOPAUSE				\
		-sDEVICE=pdfwrite			\
		-sPAPERSIZE=$PAPER			\
		-sOutputFile="$2"			\
		/tmp/$$.ps				\
		-c quit

	rm /tmp/$$.ps
	;;
    *)
	Ted --printToFile "$1" /tmp/$$.ps

	gs -q	-dNOPAUSE				\
		-sDEVICE=pdfwrite			\
		-sOutputFile="$2"			\
		/tmp/$$.ps				\
		-c quit

	rm /tmp/$$.ps
	;;
esac

