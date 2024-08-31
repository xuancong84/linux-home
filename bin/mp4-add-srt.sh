#!/bin/bash

if [ $# == 0 ]; then
	echo "Usage: $0 input.mp4 sub1.srt:lang1 (sub2.srt:lang2 ...)"
	echo "This will discard all existing subtitle tracks in the input MP4."
	exit
fi

pycode="
import os,sys
langs=[(s.split(':')+[s.split('.')[0]])[:2] for i,s in enumerate(sys.argv[2:])]
print(f'ffmpeg -y -i {sys.argv[1]}'+''.join([' -i '+p[0] for p in langs])+' -map 0:v -map 0:a'
+''.join([f' -map {i+1}' for i in range(len(langs))])+' -c:v copy -c:a copy -c:s mov_text'
+''.join([f' -metadata:s:s:{i} language={p[1]} -metadata:s:s:{i} handler_name={p[1]}' for i,p in enumerate(langs)])
+f' {sys.argv[1]}.mp4')
"

#python3 -c "$pycode" "$@"; exit

python3 -c "$pycode" "$@" | while read line; do $line ; done

echo "If successfull, output file should be $1.mp4"
