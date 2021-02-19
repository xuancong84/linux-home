#!/usr/bin/env bash

write=
if [ ! -s ~/wakeup.enabled ]; then
	write=True
fi


find /sys/devices -iname wakeup | while read f; do
	if [ ! -d "$f" ]; then
		if [ `cat "$f"` == enabled ]; then
			echo disabled >"$f"
			echo "$f =>" `cat "$f"`
			if [ "$write" ]; then
				echo "$f" >>~/wakeup.enabled
			fi
		else
			echo "$f" = `cat "$f"`
		fi
	fi
done

echo PBTN >>/proc/acpi/wakeup


