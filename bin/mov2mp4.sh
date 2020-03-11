#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage: $0 input.mov output.mp4"
	exit 1
fi

ffmpeg -i "$1" -vcodec h264 -acodec aac "$2"

