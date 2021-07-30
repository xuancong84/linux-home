#!/usr/bin/env bash

if [ $# == 0 ]; then
	echo "Usage: $0 output-dir" >&2
	exit 0
fi

OUTDIR="$1"

# Prepare task list
tasklist=()
STR="`cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list | grep '^deb' | sed 's:\[[^]]*\]::g; s:  *: :g' | sort | uniq`"
while read line; do
	its=( $line )
	while [ ${#its[@]} -ge 4 ]; do
		tasklist+=( ${its[1]} ${its[2]} ${its[-1]} )
		unset its[-1]
	done
done <<< "$STR"
N=$[${#tasklist[@]}/3]
echo "In total there are $N pools to clone"


wget_recurse_all () { wget -r -np -l 9999 -P $OUTDIR --reject-regex '.*\?.*' "$@"; }
wget_current_dir () { wget -r -np -l 1    -P $OUTDIR --reject-regex "(.*\?.*)|($1/.*/.*)" "$@"; }
get_md5_section () { awk 'BEGIN{a=0}{if($1=="MD5Sum:")a=1; else if($1 ~ "^SHA")a=0; else if(a>0)print $0}'; }


# Start cloning
mkdir -p $OUTDIR
for i in `seq 0 $[N-1]`; do
	url=${tasklist[i*3]%/}
	dist=${tasklist[i*3+1]}
	pool=${tasklist[i*3+2]}
	url_nohttp=$(echo $url | sed "s:^.*\://::g")

	# Firstly, download the distrib root index with timestamp awareness
	wget_current_dir -N $url/dists/$dist/

	# Secondly, download the distrib's pool index with timestamp awareness
	wget_recurse_all -N $url/dists/$dist/$pool/

	# For now, simply fetch all in the pool
	wget_recurse_all -N $url/pool/
done

# Delete all index.html that previews directory content
find $OUTDIR -iname '*.html' | xargs rm -rf

