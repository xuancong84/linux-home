#!/bin/bash

if [ $# -lt 3 ]; then
	echo "Usage: $0 ssh-target-username@address serverIP:serverPort:clientIP:clientPort"
	echo "This establishes a reverse SSH tunnel persistently."
	exit
fi

target="$1"
binding="$2"

IFS=: read -ra parts <<<"$binding"
port=${parts[-3]}

while :; do
	ssh -o ServerAliveInterval=30 -o ConnectTimeout=3 -o ConnectionAttempts=1 -o ExitOnForwardFailure=yes -v -N -R "$binding" "$target"
	pid=`ssh $target sudo lsof -t -i :$port`
	if [ "$pid" ]; then
		ssh $target sudo kill -9 $pid
	fi
	sleep 3
done

