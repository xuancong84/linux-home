#!/usr/bin/env bash

set -e

# get wine arch and version
source ~/.PlayOnLinux/wineprefix/Office2010/playonlinux.cfg
WINEBIN="~/.PlayOnLinux/wine/linux-$ARCH/$VERSION/bin/wine"

# go into directory and replace all shortcuts
cd ~/.local/share/applications

find . -iname '*.desktop' \
| while read file; do
	if [ `cat "$file" | grep wineprefix/Office2010 | wc -l` -gt 0 ]; then
		sed -i "s:[^ ]*wine :$WINEBIN :g" "$file"
		echo -n '+'
	else
		echo -n '-'
	fi
done
echo

