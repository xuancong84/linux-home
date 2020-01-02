#!/bin/bash


if [ $# -lt 3 ]; then
	echo "Usage: $0 [--options] start-time end-time input-file [output-file]"
	echo "--recode : do re-encoding, otherwise the start/end time will be aligned to the nearest keyframe"
	echo "--crf : set video quality (constant rate factor, default is 25, lossless is 0, 51 is worst, ffmpeg's default is 23)"
	echo "time format: ss or hh:mm:ss or -ss or -hh:mm:ss, negative number means from end of the video, empty string means from start until end"
	echo "If <output-file> is missing, input-file will be modified"
	exit 1
fi

# set options
opt_copy="-acodec copy -vcodec copy"
opt_crf="-crf 21"
while [[ "$1" =~ ^-- ]]; do
	if [ "$1" == "--recode" ]; then
		opt_copy=""
		shift
	elif [ "$1" == "--crf" ]; then
		opt_crf="-crf $2"
		shift
		shift
	fi
done


# get start/end time
pycode="import os,sys
a1='$1'
a2='$2'
D=float(sys.argv[1])

def to_sec(s):
	if s=='': return 0
	if s.startswith('-'): return -to_sec(s[1:])
	if ':' in s:
		return sum([float(j)*(60**i) for i,j in enumerate(s.split(':')[::-1])])
	return float(s)

t1=(to_sec(a1)+D)%D
t2=(to_sec(a2)+D)%D
dur=t2-t1

print(('-ss %f'%t1 if a1 else '') + (' -t %f'%dur if a2 else ''))

"
shift
shift

dur=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"`
opt_dur=$(python3 -c "$pycode" $dur)


# get input/output filename
f_in="$1"
if [ $# -ge 2 ]; then
	f_out="$2"
else
	f_out="$f_in"
fi

# get temp filename
f_tmp="$(mktemp $f_out.XXXXXX.mp4)"


# MAIN
ffmpeg -y -i "$f_in" $opt_dur $opt_copy "$f_tmp"
mv "$f_tmp" "$f_out"

