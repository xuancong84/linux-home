#!/bin/bash

set -e -x -o pipefail

if [ $# -lt 2 ]; then
	echo "Usage: $0 binary-executable output-folder" >&2
	exit
fi

BIN="`which \"$1\"`"
OUT="$2"

mkdir -p $OUT

cp $BIN $OUT/
ldd -v "$BIN" | sed 's:([^)]*)::g; /:/d' | awk '{if(NF>0)print $NF}' | sort | uniq \
	| while read f; do
		if [ -s "$f" ]; then
			cp -vf "$f" $OUT/
		fi
	done

BINBASE="`basename \"$BIN\"`"
SCRIPT=$OUT/"$BINBASE".sh

echo "#!/bin/bash
path=\"\`dirname \\\"\$0\\\"\`\"
LD_LIBRARY_PATH=\$path:\$LD_LIBRARY_PATH \$path/$BINBASE \"\${@}\"
" >$SCRIPT

chmod +x $SCRIPT

