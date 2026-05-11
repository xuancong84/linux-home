#!/usr/bin/env bash

if [ $# == 0 ]; then
	echo "Usage: $0 [-first_N_lines] [input_files] ..." >&2
	exit 0
fi

N=200
FS_MAX=100000
if [[ "$1" =~ ^-[0-9]+$ ]]; then
	N=${1:1}
	shift
fi

files=()
for f in "$@"; do
	FILE_PATH="$f"
	FILENAME=$(basename -- "$FILE_PATH")
	# Strip extensions to create a clean base name for the output
	BASE_NAME="${FILENAME%.*}"
	BASE_NAME="${BASE_NAME%.csv}"
	
	# Generate a unique path using a timestamp and a random number
	EXTRACTED_PATH="/tmp/${BASE_NAME}.$RANDOM.csv"
	
	case "$FILE_PATH" in
	    *.csv|*.CSV)
			EXTRACTED_PATH="$FILE_PATH"
	        ;;
	    *.gz)
	        gunzip -c "$FILE_PATH" > "$EXTRACTED_PATH"
	        ;;
	    *.zip)
	        # Zip files might contain multiple files; find the first CSV
	        TEMP_DIR=$(mktemp -d)
	        unzip -q "$FILE_PATH" -d "$TEMP_DIR"
	        find "$TEMP_DIR" -name "*.csv" -exec mv {} "$EXTRACTED_PATH" \; -quit
	        rm -rf "$TEMP_DIR"
	        ;;
	    *.xz)
	        xz -dc "$FILE_PATH" > "$EXTRACTED_PATH"
	        ;;
	    *.rar)
	        # Prints file content to stdout
	        unrar p -inul "$FILE_PATH" > "$EXTRACTED_PATH"
	        ;;
	    *.7z)
	        # Extracts to stdout
	        7z e "$FILE_PATH" -so > "$EXTRACTED_PATH" 2>/dev/null
	        ;;
	    *)
	        echo "Unsupported format: $FILE_PATH"
	        exit 1
	        ;;
	esac
	f="$EXTRACTED_PATH"
	if [ `stat -c %s "$f"` -ge $FS_MAX ]; then
		sn=`basename "$f" | sed "s:[^a-zA-Z0-9,-]:_:g"`
		tmp=/tmp/$sn.$RANDOM.csv
		zcat -f "$f" | head -$N >$tmp
		files+="$tmp"
	else
		tmp="$f"
	fi
	echo "Showing $tmp ..."
	gnumeric $tmp &
done
wait
rm -rf $files

