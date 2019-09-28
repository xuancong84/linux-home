
if [ $# -lt 2 ]; then
	echo "Usage: $0 input-file/input-folder output-file/output-folder"
	echo "Usage: $0 input-folder output-photo-folder output-video-folder"
	exit 1
fi

if [ -f "$1" ]; then
	# single file mode
	set -e
	if [[ "$1" == *.mp4 ]] || [[ "$1" == *.MP4 ]]; then
		mp4-compress.sh "$1" "$2"
	else
		jpegoptim.sh "$1" "$2"
	fi
	exit 0
fi


IN_DIR="$1"
if [ $# == 2 ]; then
	OUT_JPG="$2"
	OUT_MP4="$2"
else
	OUT_JPG="$2"
	OUT_MP4="$3"
fi

jpegoptim.sh "$IN_DIR" "$OUT_JPG"

len=${#IN_DIR}
find "$IN_DIR" -iname "*.mp4" | while read line; do
	fn="$line"
	mp4-compress.sh "$fn" "$OUT_MP4"/${fn:$len}
done



