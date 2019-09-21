

if [ $# -lt 2 ]; then
	echo "Usage: $0 input.mp4/input-folder output.mp4/output-folder [bitrate=2600k] [preset=slow]"
	echo "Preset levels are: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow and placebo"
	echo "If the output-folder ends with a slash, it will skip existing non-empty files"
fi

set +e

f_in="$1"
f_out="$2"

SKIP=
if [[ $f_out == */ ]]; then
	SKIP=1
fi

BR=2600k
if [ "$3" ]; then
	BR="$3"
fi

PRESET=slow
if [ "$4" ]; then
	PRESET="$4"
fi

function conv {
	ffmpeg -y -i "$1" -c:v libx265 -b:v $BR -async 1 -vsync 1 -preset $PRESET -x265-params "pass=1:pools=6" -an -f mp4 /dev/null && \
	ffmpeg -y -i "$1" -c:v libx265 -b:v $BR -async 1 -vsync 1 -preset $PRESET -x265-params "pass=2:pools=6" -c:a aac -b:a 128k "$2"
}

if [ -f "$f_in" ]; then
	conv "$f_in" "$f_out"
else
	len=${#f_in}
	find "$f_in" -iname "*.mp4" | while read line; do
		outpath=$f_out/${line:$len}
		if [ "$SKIP" ] && [ -s "$outpath" ]; then
			echo "Skipping '$outpath'"
			continue
		fi
		echo "Start compressing '$line' => '$outpath'"
		mkdir -p "`dirname $outpath`"
		conv "$line" "$outpath"
		echo "Finished compressing '$line' => '$outpath'"
	done
fi

rm -f x265_2pass.log*


