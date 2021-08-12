# ~/.profile: executed by the command interpreter for login shells.

if [ -s ~/.bashrc ]; then
	source ~/.bashrc
fi

if [ ! "$DISPLAY" ]; then
	export DISPLAY=localhost:0
fi

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export HISTSIZE=1000000
export EDITOR=vim

export PATH=$HOME/bin:/usr/local/bin:$PATH
export CPLUS_INCLUDE_PATH=$HOME/include:$CPLUS_INCLUDE_PATH
export C_INCLUDE_PATH=$HOME/include:$C_INCLUDE_PATH
export LIBRARY_PATH=$HOME/lib:$LIBRARY_PATH

alias l='less'
alias ll='ls -alG'
alias lr='less -r'
alias t='top'
alias gtop='watch -n 1 nvidia-smi'
alias c='cat'
alias p='ps aux | l'
alias ka='killallbyname'
alias ac='zcat -f'
alias killstop='kill $(jobs -p)'
alias git_gc_all='git reflog expire --expire=now --all && git gc --aggressive --prune=now'
alias wan_ip='dig +short myip.opendns.com @resolver1.opendns.com'
alias sus="sudo -H env XAUTHORITY=$HOME/.Xauthority su"
alias sul='sudo su -l'

adb_broadcast() {
	if [ $# == 0 ]; then
		echo "Usage: $0 <file-fullpath>"
		echo "This make all apps aware of the media file newly copied to Android; <file-fullpath> must starts with /sdcard/"
		return 1
	fi
	adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://$1
}

killallbyname() {
	if [ $# == 0 ]; then
		echo -e "Usage: ${FUNCNAME[0]} proc-search-pattern [-N]
This kills all processes having a command line matching the \033[1;31mgrep\033[0m pattern.
N: signal for the kill
0 - ? 
1 - SIGHUP - ?, controlling terminal closed, 
2 - SIGINT - interupt process stream, ctrl-C 
3 - SIGQUIT - like ctrl-C but with a core dump, interuption by error in code, ctl-/ 
4 - SIGILL 
5 - SIGTRAP 
6 - SIGABRT 
7 - SIGBUS 
8 - SIGFPE 
9 - SIGKILL - terminate immediately/hard kill, use when 15 doesn't work or when something disasterous might happen if process is allowed to cont., kill -9 
10 - SIGUSR1 
11 - SIGEGV 
12 - SIGUSR2
13 - SIGPIPE 
14 - SIGALRM
15 - SIGTERM - terminate whenever/soft kill, typically sends SIGHUP as well? 
16 - SIGSTKFLT 
17 - SIGCHLD 
18 - SIGCONT - Resume process, ctrl-Z (2nd)
19 - SIGSTOP - Pause the process / free command line, ctrl-Z (1st)
20 - SIGTSTP 
21 - SIGTTIN 
22 - SIGTTOU
23 - SIGURG
24 - SIGXCPU
25 - SIGXFSZ
26 - SIGVTALRM
27 - SIGPROF
28 - SIGWINCH
29 - SIGIO 
29 - SIGPOLL 
30 - SIGPWR - shutdown, typically from unusual hardware failure 
31 - SIGSYS" >&2
		return 0
	else
		ps aux | grep "$1" | sed '/grep/d' | xargs kill $2
	fi
}
lowercase() {
	awk '{print tolower($0)}'
}
uppercase() {
	awk '{print toupper($0)}'
}
random_string() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${1:-32} | head -n 1
}
gn() {
    if [ $# == 0 ]; then
        echo "Usage: gnumeric [input.csv/input.csv.gz]" >&2
        return
    fi
    if [[ "$1" =~ .*gz$ ]]; then
        RAND=$RANDOM
        zcat -f "$1" >/tmp/$RAND.csv
        gnumeric /tmp/$RAND.csv
        rm -f /tmp/$RAND.csv
    else
        gnumeric "$1"
    fi
}
create_ssl_x509() {
	if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then echo "Usage: $0 [days=3650] [encryption=rsa:2048] [output-prefix=ssl(.key+.crt)]" >&2; return; fi
	days=3650
	if [ "$1" ]; then days="$1"; fi
	enc="rsa:2048"
	if [ "$2" ]; then enc="$2"; fi
	out=ssl
	if [ "$3" ]; then out="$3"; fi
	openssl req -x509 -sha256 -nodes -days $days -newkey $enc -keyout $out.key -out $out.crt
}
ctop() {
    watch -n 1 "cat /proc/cpuinfo | grep '^cpu MHz'"
}
mdcd(){
	mkdir -p "$1" && cd "$1"
}
set_nvidia() {
	__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia
}
set_intel() {
	unset __NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME
}

# multi-line sed
alias sedm="sed -e '1h;2,\$H;\$!d;g' -e"

# python 3 test
alias py3="~/anaconda3/bin/python -i -c \"import os,sys,re,math;import pandas as pd;import numpy as np;from collections import *\""
alias apy="~/anaconda3/bin/python"

shopt -s direxpand

# `less` can view archives directly (.tar.gz, .zip, etc.)
export LESSOPEN="| /usr/bin/lesspipe %s";
export LESSCLOSE="/usr/bin/lesspipe %s %s";

export PS1="\[\e]0;\u@\h: \w\a\]\[\e[1;35m\]\u\[\e[0m\]@\[\e[1;36m\]\H\[\e[0m\]:\[\e[1;32m\]\w\[\e[0m\]\[\e[1;32m\]$\[\e[0m\] "
