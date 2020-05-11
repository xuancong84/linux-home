
if [ $# -lt 3 ]; then
	echo "Usage: $0 factor input.mp4 output.mp4"
	echo ""
	exit 1
fi

f=`python3 -c "print(1.0/$1)"`
ffmpeg -itsscale $f -i "$2" "$3"

