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

# install XIM (apt install uim-xim) so that you can switch input method over X11 forwarding
IM_METHOD=fcitx
export GTK_IM_MODULE=$IM_METHOD
export QT_IM_MODULE=$IM_METHOD
export XMODIFIERS="@im=$IM_METHOD"
export sshkh="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

alias l='less'
alias ll='ls -alG --color=auto'
alias lr='less -r'
alias t='top'
alias gtop="watch -n 1 \"nvidia-smi | grep '^| \{1,8\}[^ ]'\""
alias c='cat'
alias p='ps aux | l'
alias ka='killallbyname'
alias ac='zcat -f'
alias killstop='kill -9 $(jobs -p)'
alias git_gc_all='git reflog expire --expire=now --all && git gc --aggressive --prune=now'
alias wan_ip='dig +short myip.opendns.com @resolver1.opendns.com'
alias sus="sudo -H env XAUTHORITY=$HOME/.Xauthority su"
alias sul='sudo su -l'

# multi-line sed
alias sedm="sed -e '1h;2,\$H;\$!d;g' -e"
alias py3="~/anaconda3/bin/python -i -c \"import os,sys,re,math,random;import pandas as pd;import numpy as np;from collections import *\""
alias apy="~/anaconda3/bin/python"

alias test_pytorch="~/anaconda3/bin/python -c 'import torch;print(torch.cuda.is_available())'"
alias test_tensorflow="~/anaconda3/bin/python -c 'import tensorflow as tf; print(tf.test.is_gpu_available())'"
test_nvcc() {
cat >/tmp/$$.cu <<EOF
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>
#include <cuda.h>
#include <cuda_runtime.h>

#define N 50000000
#define MAX_ERR 1e-6

__global__ void vector_add(float *out, float *a, float *b, int n) {
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid < n) out[tid] = a[tid] + b[tid];
}

int main(){
    float *a, *b, *out, *d_a, *d_b, *d_out;
	printf("Preparing data buffer of size %d in CPU memory ...", N); fflush(stdin);
    a   = (float*)malloc(sizeof(float) * N);
    b   = (float*)malloc(sizeof(float) * N);
    out = (float*)malloc(sizeof(float) * N);
    for(int i = 0; i < N; i++){
        a[i] = 1.0f;
        b[i] = 2.0f;
    }
	printf("\nCopying data CPU memory to GPU memory ..."); fflush(stdin);
    cudaMalloc((void**)&d_a, sizeof(float) * N);
    cudaMalloc((void**)&d_b, sizeof(float) * N);
    cudaMalloc((void**)&d_out, sizeof(float) * N);
    cudaMemcpy(d_a, a, sizeof(float) * N, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, sizeof(float) * N, cudaMemcpyHostToDevice);
	printf("\nCalculating addition on GPU ..."); fflush(stdin);
    vector_add<<<(N+256)/256,256>>>(d_out, d_a, d_b, N);
	printf("\nCopying data back from GPU memory to CPU memory ..."); fflush(stdin);
    cudaMemcpy(out, d_out, sizeof(float) * N, cudaMemcpyDeviceToHost);
	printf("\nValidating results ..."); fflush(stdin);
    for(int i = 0; i < N; i++)
        assert(fabs(out[i] - a[i] - b[i]) < MAX_ERR);
    printf("\033[1;92mPASSED\033[0m\n"); fflush(stdin);
    cudaFree(d_a); cudaFree(d_b); cudaFree(d_out);
    free(a); free(b); free(out);
}
EOF
	nvcc -o /tmp/$$.out /tmp/$$.cu && nvprof /tmp/$$.out
	rm -rf /tmp/$$.*
}

mp4_shrink() {
	if [ $# == 0 ]; then
		echo "Usage: $0 input.mp4 output.mp4 [crf=30]"
		echo "ffmpeg -i input.mp4 -vcodec libx265 -crf 30 output.mp4"
		exit
	fi
	crf=30
	if [ $# -ge 3 ]; then
		crf=$3
	fi
	ffmpeg -i "$1" -vcodec libx265 -crf $crf "$2"
}

swapfile() {
	if [ $# != 2 ]; then
		echo "Usage: $0 file1 file2"
		echo "Swap the content of file1 and file2"
		return 1
	fi
	tmp="`dirname \"$1\"`/$$"
	mv "$1" "$tmp"
	mv "$2" "$1"
	mv "$tmp" "$2"
}

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
		ps aux | grep "$1" | sed '/grep/d' | awk '{print $2}' | xargs kill $2
	fi
}
lowercase() {
	awk '{print tolower($0)}'
}
uppercase() {
	awk '{print toupper($0)}'
}
random_string() {
    cat /dev/urandom | tr -dc 'a-km-zA-HJ-NP-Z2-9' | fold -w ${1:-32} | head -n 1
}
m4a_concat() {
	if [ $# -lt 3 ]; then
		echo "Usage: $0 file1.m4a file2.m4a combined-out.m4a" >&2
		return 1
	fi
	ffmpeg -i "$1" -acodec copy "$3.1.aac"
	ffmpeg -i "$2" -acodec copy "$3.2.aac"
	cat "$3.1.aac" "$3.2.aac" >"$3.aac"
	ffmpeg -i "$3.aac" -acodec copy -bsf:a aac_adtstoasc "$3"
	rm -f "$3".*
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

mdcd() {
	mkdir -p "$1" && cd "$1"
}

set_nvidia() {
	__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia
}
set_intel() {
	unset __NV_PRIME_RENDER_OFFLOAD __GLX_VENDOR_LIBRARY_NAME
}
norm_vol() {
	ffmpeg-normalize "$1" -o $$.mp4 -c:a aac -t -12 -nt rms -f
	if [ $? == 0 ]; then
		mv $$.mp4 "$1"
	fi
}
shopt -s direxpand

# `less` can view archives directly (.tar.gz, .zip, etc.)
export LESSOPEN="| /usr/bin/lesspipe %s";
export LESSCLOSE="/usr/bin/lesspipe %s %s";

export PS1="\[\e]0;\u@\h: \w\a\]\[\e[1;35m\]\u\[\e[0m\]@\[\e[1;36m\]\H\[\e[0m\]:\[\e[1;32m\]\w\[\e[0m\]\[\e[1;32m\]$\[\e[0m\] "
