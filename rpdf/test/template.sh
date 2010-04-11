#!/bin/bash -ex

TMPFILE=$(tempfile)
trap 'echo "removing $TMPFILE"; rm -f $TMPFILE' INT TERM EXIT
