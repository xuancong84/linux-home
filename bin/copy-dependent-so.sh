#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage: $0 input-executable-file output-folder"
	exit 1
fi

mkdir -p "$2"
ldd -v "$1" | grep '=>' | sed "s:([^)]*)::g" | awk '{print $NF}' | sort | uniq | while read f; do cp -vf "$f" "$2/"; done
