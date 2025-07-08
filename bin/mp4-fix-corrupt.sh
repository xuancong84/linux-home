#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage: $0 input.mp4 outputmp4"
	exit
fi

ffmpeg -err_detect ignore_err -i "$1" -c copy "$2"

