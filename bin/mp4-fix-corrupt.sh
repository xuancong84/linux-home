#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage: $0 input.mp4 output.mp4"
	exit
fi

ffmpeg -err_detect ignore_err -i "$1" -c copy -map 0 -c:s mov_text "$2"

