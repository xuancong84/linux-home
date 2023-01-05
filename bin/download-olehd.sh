#!/bin/bash

out_dir=douluo

mkdir -p $out_dir

for i in {1..141}; do
	if [ -s $out_dir/$i.mp4 ]; then
		continue
	fi
	rm -vrf $out_dir/$i.mp4*
	url="https://www.olehd.com/index.php/vod/play/id/5098/sid/1/nid/$i.html"
	m3u8=`wget -O - $url | grep -o '"url":"http[^,]*m3u8"' | sed 's/"url"://g' | sed 's:["\\]::g'`
	echo "Start to download $m3u8 ..."
	yt-dlp --output $out_dir/$i.mp4 --external-downloader-args "-http_seekable 0" $m3u8
	sleep 5
done

