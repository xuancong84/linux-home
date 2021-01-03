#!/usr/bin/env bash

set -e -o pipefail

if [ $# == 0 ]; then
	echo "Usage: $0 <version> [release-type=staging]" >&2
	echo -e "For example:\n$0 5.21 devel\n$0 5.22 staging" >&2
	exit 1
fi

VER="$1"

TYPE=staging
if [ "$2" ]; then
	TYPE="$2"
fi

distro=`lsb_release -a 2>/dev/null | grep "^Distributor ID" | awk '{print tolower($NF)}'`
codename=`lsb_release -a 2>/dev/null | grep "^Codename" | awk '{print tolower($NF)}'`

wget -c https://dl.winehq.org/wine-builds/$distro/dists/$codename/main/binary-amd64/wine-$TYPE-amd64_$VER~${codename}_amd64.deb
wget -c https://dl.winehq.org/wine-builds/$distro/dists/$codename/main/binary-amd64/wine-${TYPE}_$VER~${codename}_amd64.deb
wget -c https://dl.winehq.org/wine-builds/$distro/dists/$codename/main/binary-amd64/winehq-${TYPE}_$VER~${codename}_amd64.deb
wget -c https://dl.winehq.org/wine-builds/$distro/dists/$codename/main/binary-i386/wine-$TYPE-i386_$VER~${codename}_i386.deb

