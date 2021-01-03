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
alias ka='killall.sh'
alias ac='zcat -f'
alias killstop='kill $(jobs -p)'
alias git_gc_all='git reflog expire --expire=now --all && git gc --aggressive --prune=now'
alias wan_ip='dig +short myip.opendns.com @resolver1.opendns.com'

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
alias py3="python3 -i -c \"import os,sys,re,math;import pandas as pd;import numpy as np;from collections import *\""
alias apy="~/anaconda3/bin/python"

shopt -s direxpand

# `less` can view archives directly (.tar.gz, .zip, etc.)
export LESSOPEN="| /usr/bin/lesspipe %s";
export LESSCLOSE="/usr/bin/lesspipe %s %s";

export PS1="\[\e]0;\u@\h: \w\a\]\[\e[1;35m\]\u\[\e[0m\]@\[\e[1;36m\]\H\[\e[0m\]:\[\e[1;32m\]\w\[\e[0m\]\[\e[1;32m\]$\[\e[0m\] "
