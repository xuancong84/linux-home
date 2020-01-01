
if [ $# == 0 ]; then
	echo "Usage: $0 [-options] input1 input2 ... output"
	echo "-recode : re-encode videos"
	echo "-copy : avoid re-encoding videos"
	exit 1
fi

mode=copy
while [[ $1 =~ ^- ]]; do
	if [ $1 == '-recode' ]; then
		mode=recode
	fi
	shift
done

args=(${*})
n_in=$[$#-1]
fout=${args[$#-1]}

set -e -o pipefail

if [ $mode == copy ]; then
	echo "Concatenating videos by copying ..."
	opt=${args[0]}
	for i in `seq $[n_in-1]`; do
		opt="$opt -cat ${args[i]}"
	done
	MP4Box $opt -out $fout
else
	echo "Concatenating videos by re-encoding ..."
	opt1="-i ${args[0]}"
	for i in `seq $[n_in-1]`; do
		opt1="$opt1 -i ${args[i]}"
	done
	opt2=
	for i in `seq 0 $[n_in-1]`; do
		opt2="$opt2 [$i:v] [$i:a]"
	done
	ffmpeg $opt1 -filter_complex "$opt2 concat=n=$n_in:v=1:a=1 [v] [a]" -map "[v]" -map "[a]" $fout
fi


