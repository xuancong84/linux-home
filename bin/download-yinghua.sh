#!/usr/bin/env bash

if [ $# == 0 ]; then
	echo "Usage: $0 http://www.yinghuacd.com/v/* [output-file.mp4]"
	exit 0
fi

url="$1"
out=output.mp4
if [ "$2" ]; then
	out="$2"
fi

set -x 

echo Random seed is $$

m3u8_url=`wget "$url" -O - | grep -o 'https[^ ]*m3u8' | head -1 | sed 's:\\\\::g'`

wget $m3u8_url -O $$.m3u8

pycode="
import os,sys,time
import urllib.request
from tqdm import tqdm
from random import random

def download(url):
	i=0
	while True:
		try:
			with urllib.request.urlopen(url) as f:
				return f.read()
		except:
			i+=1
			print(f'Connection timeout: {i}', file=sys.stderr)
			time.sleep(10)

for ii,url in enumerate(tqdm(sys.stdin.read().splitlines())):
	S=download(url)
	posi=S[:1000].find(b'FFmpeg')
	if posi<0:
		print('FFmpeg not found', file=sys.stderr)
		sys.exit(1)
	sys.stdout.buffer.write(S[posi-25:])
	if ii and ii%10==0:
		time.sleep(10+10*random())
"

cat $$.m3u8 | grep '^http' | python3 -c "$pycode" >$$.m2ts

ffmpeg -i $$.m2ts -vcodec libx265 -crf 25 -acodec ac3 -vf "yadif" $out
rm -f $$.*

echo "Finished: output written to $out"
