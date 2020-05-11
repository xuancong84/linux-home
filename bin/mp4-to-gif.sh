
if [ $# -lt 2 ]; then
	echo "Usage: $0 [options] input.mp4 output.gif"
	echo "-fps : specify frames-per-second"
	echo "-width : specify width"
	exit 1
fi

options=
while [[ "$1" =~ ^- ]]; do
	if [ "$1" == -fps ]; then
		options="fps=$2,$options"
	elif [ "$1" == -width ]; then
		options="scale=$2:-1:flags=lanczos,$options"
	else
		echo "Error: unknown option $1"
		exit 1
	fi
	shift
	shift
done

ffmpeg -i "$1" -vf "${options}split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "$2"

