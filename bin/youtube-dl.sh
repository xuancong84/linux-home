#!/bin/bash

if [ $# == 0 ]; then
	echo "Usage: $0 <youtube-URL> [output-file] [\"format-options\"]"
	exit 1
fi

opt=
if [ $# -ge 2 ]; then
	opt="-o $2"
fi

fopt="-f bestvideo+mp4"
if [ $# -ge 3 ]; then
	aopt="$3"
fi

youtube-dl $fopt $opt $1

