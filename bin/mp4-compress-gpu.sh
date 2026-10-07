#!/bin/bash

if [ $# == 0 ]; then
	echo "Usage: $0 input.mp4 output.mp4 [cq=32] [preset=slow] [options...]"
	echo "This uses hardware HEVC to re-encode video files using ffmpeg."
	echo 'To resize video: -vf "scale=-2:1080"'
	exit
fi

# -vf "scale=-2:1080"

for f in `ls $IN`; do
	ffmpeg -y -hwaccel cuda -i "$1" \
		-c:v hevc_nvenc \
		-cq ${3:-32} -preset ${4:-slow} \
		-c:a copy \
		"${@:5}" \
		-c:s mov_text "$2"
done

