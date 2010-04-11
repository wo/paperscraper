#! /bin/sh

DIR=`dirname $0`

if [ $# < 2 ]; then
    echo "usage: merge-classmap <mnist-prefix> ... (at least 2)"
    exit
fi

CLASSMAP=`mktemp`
UNICODES=`mktemp`
for I in $@; do
    $DIR/apply-classmap $I-classmap <$I-labels-ubyte >$UNICODES
    $DIR/build-classmap $CLASSMAP <$UNICODES >$I-labels-ubyte
done

for I in $@; do
    cp $UNICODES $I-classmap
done

rm -f $CLASSMAP $UNICODES
