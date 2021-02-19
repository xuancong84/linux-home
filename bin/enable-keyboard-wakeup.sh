#!/usr/bin/env bash


cat ~/wakeup.enabled | while read f; do
	echo enabled >"$f"
	echo "$f =>" `cat "$f"`
done

