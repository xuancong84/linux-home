#!/bin/bash

if [ $# == 0 ]; then
	echo "Usage: $0 <input.mp3> <speed-ratio> (output.mp3)"
	echo "This changes the speed of the audio (without changing pitch), output to input.mp3.mp3"
	exit
fi

out="$1.mp3"
if [ "$3" ]; then
	out="$3"
fi

ffmpeg -i "$1" -filter:a "atempo=$2" $out

