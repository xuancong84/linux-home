
set -e -o pipefail

if [ $# == 0 ]; then
	echo "Usage: $0 input-file/input-folder output-folder [-m60]"
	echo "It converts recursively, preserving folder structure and filenames"
	exit
fi

input=$1
output=$2

if [ -f $input ]; then
	len=`dirname "$input"`
	len=${#len}
else
	len=${#input}
fi

if [ "$3" ]; then
	opt="$3"
else
	opt="-m60"
fi

mkdir -p $output

find $input -iregex ".*.jpe?g" | while read line; do
	outpath=$output/`dirname "${line:$len}"`
	#echo $len $outpath && exit
	mkdir -p $outpath
	jpegoptim -o -p $opt --strip-all -d"$outpath" "$line"
done


