#!/bin/bash
# Turn off screen + throttle all CPUs to min freq; when screen wakes, restore CPU max freq.
# Usage: toggle-screen-cpu.sh [N]    (restore to Nth-highest freq: 0=highest, 1=2nd-highest,
#                                      -1=each core's previous max freq (default))
# Works on X11 and KDE Wayland. Needs sudo for writing cpufreq sysfs.

n=${1:--1}
declare -A prev

set_max() {  # $1 = "min" | "max"
	for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
		if [ $1 = min ]; then
			prev[$c]=$(<$c/scaling_max_freq)
			f=$(<$c/cpuinfo_min_freq)
		elif [ $n -lt 0 ]; then
			f=${prev[$c]}
		elif [ -f $c/scaling_available_frequencies ]; then  # acpi-cpufreq: descending list
			f=$(tr ' ' '\n' <$c/scaling_available_frequencies | grep . | sort -rn | sed -n "$((1+n))p")
		else  # intel_pstate/amd-pstate: no list, use 100MHz steps below max
			f=$(( $(<$c/cpuinfo_max_freq) - n*100000 ))
		fi
		echo $f | sudo tee $c/scaling_max_freq >/dev/null
	done
}

screen_on() {
	for c in /sys/class/drm/card*-*; do
		[ "$(<$c/status)" = connected ] && [ "$(<$c/dpms)" = On ] && return 0
	done
	return 1
}

set_max min
sleep 0.5  # let key release settle so it doesn't immediately wake the screen
if [ "$XDG_SESSION_TYPE" = wayland ]; then
	kscreen-doctor --dpms off
else
	xset dpms force off
fi
for i in {1..50}; do screen_on || break; sleep 0.1; done  # wait for off (max 5s)
while ! screen_on; do sleep 1; done
set_max max
