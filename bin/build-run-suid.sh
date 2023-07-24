#!/bin/bash

if [ "$1" == '-h' ] || [ "$1" == "--help" ] || [ "`whoami`" != root ] ;then
	echo "Usage: $0 < lines-of-{item}s"
	echo "Usage: $0 {item}"
	echo 'This program builds SUID programs that allow users to run commands as root. Each {item} is of format "program-name command-line-containing-space"'
	exit
fi

build() {
	echo "$@" >&2
	cat >$1.cpp <<EOF
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[]){
	setuid(0);
	return system(R"a$$a(${@:2})a$$a");
}
EOF
	g++ -o $1 $1.cpp
	chown root:root $1 && chmod +s $1
}

if [ $# -ge 2 ]; then
	build "$@"
else
	while read line; do
		[ "$line" ] && [[ ! $line =~ ^#.* ]] && build $line
	done
fi

