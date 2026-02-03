# ~/.profile: executed by the command interpreter for login shells.

if [ -s ~/.bashrc ]; then
	source ~/.bashrc
fi

if [ ! "$DISPLAY" ]; then
	export DISPLAY=localhost:0
fi

ulimit -s unlimited

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
alias b='btop'
alias gtop="watch -n 1 \"nvidia-smi | grep '^| \{1,8\}[^ ]'\""
alias c='cat'
alias p='ps aux | l'
alias ka='killallbyname'
alias ac='zcat -f'
alias killstop='kill -9 $(jobs -p)'
alias git_gc_all='git reflog expire --expire=now --all && git gc --aggressive --prune=now'
alias wan_ip='dig +short myip.opendns.com @resolver1.opendns.com'
alias showmyip='curl https://ipinfo.io/ip'
alias sus="sudo -H env XAUTHORITY=$HOME/.Xauthority su"
alias sul='sudo -i'
alias open=xdg-open
alias yd='~/anaconda3/bin/yt-dlp --embed-subs -R infinite --socket-timeout 3 --cookies-from-browser firefox:/home/xuancong/.mozilla/firefox/'
# For ydvr, browser cookie MUST NOT be specified, or mono video will be downloaded
alias ydvr='~/anaconda3/bin/yt-dlp -R infinite --socket-timeout 3 --user-agent "" --extractor-args "youtube:player-client=all"'
alias ta='tmux a'
alias tls='tmux ls'
alias p8='ping 8.8.8.8'
alias pg='ping www.google.com'
alias xp_start='xpra start :100  --start-child=xterm --start-via-proxy=no --opengl=yes'
alias xp_list='xpra list'
alias xp_stop='xpra stop :100'
alias xp_attach='xpra attach :100'
alias ld_debug='LD_DEBUG=libs,files VK_LOADER_DEBUG=all'

# multi-line sed
alias sedm="sed -e '1h;2,\$H;\$!d;g' -e"
alias py3="~/anaconda3/bin/python -i -c \"import os,sys,re,math,random;import pandas as pd;import numpy as np;from collections import *\""
alias apy="~/anaconda3/bin/python"

alias test_pytorch="~/anaconda3/bin/python -c 'import torch;print(torch.cuda.is_available())'"
alias test_tensorflow="~/anaconda3/bin/python -c 'import tensorflow as tf; print(tf.test.is_gpu_available())'"

test_tensorflow_full () {
  pycode="
import numpy as np
import tensorflow as tf
print('TensorFlow version:', tf.__version__)

with np.load('/usr/share/datasets/mnist.npz') as f:
    x_train, y_train = f['x_train'], f['y_train']
    x_test,  y_test  = f['x_test'],  f['y_test']

x_train, x_test = x_train / 255.0, x_test / 255.0

model = tf.keras.models.Sequential([
  tf.keras.layers.Flatten(input_shape=(28, 28)),
  tf.keras.layers.Dense(128, activation='relu'),
  tf.keras.layers.Dropout(0.2),
  tf.keras.layers.Dense(10)
])

loss_fn = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
model.compile(optimizer='adam', loss=loss_fn, metrics=['accuracy'])

model.fit(x_train, y_train, epochs=5)
model.evaluate(x_test, y_test, verbose=2)

probability_model = tf.keras.Sequential([model, tf.keras.layers.Softmax()])
print(probability_model(x_test[:5]))
  ";
  PYTHONPATH=/opt/anaconda3/PYTHONPATH/tf /opt/anaconda3/bin/python -c "$pycode"
}

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
	nvcc -o /tmp/$$.out /tmp/$$.cu && nvprof /tmp/$$.out || /tmp/$$.out
	rm -rf /tmp/$$.*
}

test_cudnn(){
	cat >/tmp/$$.cu <<EOF
// test-cudnn.cu
// Build (typical Ubuntu):
//   nvcc -O2 test-cudnn.cu -lcudnn -o test-cudnn
// Run:
//   ./test-cudnn

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <cuda_runtime.h>
#include <cudnn.h>

#define CHECK_CUDA(call) do {                                      \
  cudaError_t _e = (call);                                         \
  if (_e != cudaSuccess) {                                         \
    fprintf(stderr, "CUDA error %s:%d: %s\n",                      \
            __FILE__, __LINE__, cudaGetErrorString(_e));           \
    std::exit(1);                                                  \
  }                                                                \
} while(0)

#define CHECK_CUDNN(call) do {                                     \
  cudnnStatus_t _s = (call);                                       \
  if (_s != CUDNN_STATUS_SUCCESS) {                                \
    fprintf(stderr, "cuDNN error %s:%d: %s\n",                     \
            __FILE__, __LINE__, cudnnGetErrorString(_s));          \
    std::exit(1);                                                  \
  }                                                                \
} while(0)

// Simple CPU reference: single batch, NCHW, single in/out channel, 2D conv
static void conv2d_cpu_nchw(
    const float* x, int H, int W,
    const float* w, int R, int S,
    float* y, int outH, int outW,
    int padH, int padW, int strideH, int strideW)
{
  for (int oh = 0; oh < outH; ++oh) {
    for (int ow = 0; ow < outW; ++ow) {
      float acc = 0.0f;
      for (int r = 0; r < R; ++r) {
        for (int s = 0; s < S; ++s) {
          int ih = oh * strideH + r - padH;
          int iw = ow * strideW + s - padW;
          if (ih >= 0 && ih < H && iw >= 0 && iw < W) {
            acc += x[ih * W + iw] * w[r * S + s];
          }
        }
      }
      y[oh * outW + ow] = acc;
    }
  }
}

int main() {
  // 1) Basic cuDNN presence check
  printf("cuDNN runtime version: %lu\n", cudnnGetVersion());

  cudnnHandle_t handle;
  CHECK_CUDNN(cudnnCreate(&handle));

  // 2) Set up a small, deterministic convolution
  // Input: N=1, C=1, H=5, W=5
  const int N = 1, C = 1, H = 5, W = 5;
  // Filter: K=1, C=1, R=3, S=3
  const int K = 1, R = 3, S = 3;
  const int padH = 1, padW = 1;
  const int strideH = 1, strideW = 1;
  const int dilationH = 1, dilationW = 1;

  // Host buffers (NCHW, but since N=C=1 it's just H*W)
  std::vector<float> h_x(H * W);
  std::vector<float> h_w(R * S);

  // Fill input with 1..25, weights with a simple pattern
  for (int i = 0; i < H * W; ++i) h_x[i] = float(i + 1);
  // A simple 3x3 kernel (not all ones, so it's a better test)
  float kernel[9] = {
    1.f,  2.f,  1.f,
    0.f,  0.f,  0.f,
   -1.f, -2.f, -1.f
  };
  for (int i = 0; i < 9; ++i) h_w[i] = kernel[i];

  // Descriptors
  cudnnTensorDescriptor_t xDesc, yDesc;
  cudnnFilterDescriptor_t wDesc;
  cudnnConvolutionDescriptor_t convDesc;

  CHECK_CUDNN(cudnnCreateTensorDescriptor(&xDesc));
  CHECK_CUDNN(cudnnCreateTensorDescriptor(&yDesc));
  CHECK_CUDNN(cudnnCreateFilterDescriptor(&wDesc));
  CHECK_CUDNN(cudnnCreateConvolutionDescriptor(&convDesc));

  CHECK_CUDNN(cudnnSetTensor4dDescriptor(
      xDesc, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, N, C, H, W));

  CHECK_CUDNN(cudnnSetFilter4dDescriptor(
      wDesc, CUDNN_DATA_FLOAT, CUDNN_TENSOR_NCHW, K, C, R, S));

  CHECK_CUDNN(cudnnSetConvolution2dDescriptor(
      convDesc,
      padH, padW,
      strideH, strideW,
      dilationH, dilationW,
      CUDNN_CROSS_CORRELATION,   // cuDNN uses cross-correlation by default
      CUDNN_DATA_FLOAT));

  // Output dims
  int outN, outC, outH, outW;
  CHECK_CUDNN(cudnnGetConvolution2dForwardOutputDim(
      convDesc, xDesc, wDesc, &outN, &outC, &outH, &outW));

  CHECK_CUDNN(cudnnSetTensor4dDescriptor(
      yDesc, CUDNN_TENSOR_NCHW, CUDNN_DATA_FLOAT, outN, outC, outH, outW));

  printf("Conv output dims: N=%d C=%d H=%d W=%d\n", outN, outC, outH, outW);

  // Device buffers
  float *d_x = nullptr, *d_w = nullptr, *d_y = nullptr;
  CHECK_CUDA(cudaMalloc(&d_x, sizeof(float) * H * W));
  CHECK_CUDA(cudaMalloc(&d_w, sizeof(float) * R * S));
  CHECK_CUDA(cudaMalloc(&d_y, sizeof(float) * outH * outW));

  CHECK_CUDA(cudaMemcpy(d_x, h_x.data(), sizeof(float) * H * W, cudaMemcpyHostToDevice));
  CHECK_CUDA(cudaMemcpy(d_w, h_w.data(), sizeof(float) * R * S, cudaMemcpyHostToDevice));
  CHECK_CUDA(cudaMemset(d_y, 0, sizeof(float) * outH * outW));

  // Choose an algorithm (simple + widely supported)
  cudnnConvolutionFwdAlgo_t algo = CUDNN_CONVOLUTION_FWD_ALGO_IMPLICIT_GEMM;

  size_t workspaceBytes = 0;
  CHECK_CUDNN(cudnnGetConvolutionForwardWorkspaceSize(
      handle, xDesc, wDesc, convDesc, yDesc, algo, &workspaceBytes));

  void* d_workspace = nullptr;
  if (workspaceBytes > 0) {
    CHECK_CUDA(cudaMalloc(&d_workspace, workspaceBytes));
  }

  const float alpha = 1.0f, beta = 0.0f;

  // 3) Run cuDNN convolution
  CHECK_CUDNN(cudnnConvolutionForward(
      handle,
      &alpha,
      xDesc, d_x,
      wDesc, d_w,
      convDesc, algo,
      d_workspace, workspaceBytes,
      &beta,
      yDesc, d_y));

  CHECK_CUDA(cudaDeviceSynchronize());

  // Copy result back
  std::vector<float> h_y(outH * outW);
  CHECK_CUDA(cudaMemcpy(h_y.data(), d_y, sizeof(float) * outH * outW, cudaMemcpyDeviceToHost));

  // 4) Validate vs CPU reference (tolerant)
  std::vector<float> ref(outH * outW);
  conv2d_cpu_nchw(
      h_x.data(), H, W,
      h_w.data(), R, S,
      ref.data(), outH, outW,
      padH, padW, strideH, strideW);

  double max_abs_err = 0.0;
  for (int i = 0; i < outH * outW; ++i) {
    double err = std::fabs(double(h_y[i]) - double(ref[i]));
    if (err > max_abs_err) max_abs_err = err;
  }

  printf("Max abs error vs CPU reference: %.8g\n", max_abs_err);

  const double tol = 1e-4; // float + conv should be exact here, but keep a safe tolerance
  if (max_abs_err <= tol) {
    printf("\033[1;92mPASSED\033[0m: cuDNN appears installed and working.\n");
  } else {
    printf("\033[1;91mFAILED\033[0m: output mismatch (possible setup/library issue).\n");
    return 2;
  }

  // Cleanup
  if (d_workspace) CHECK_CUDA(cudaFree(d_workspace));
  CHECK_CUDA(cudaFree(d_x));
  CHECK_CUDA(cudaFree(d_w));
  CHECK_CUDA(cudaFree(d_y));

  CHECK_CUDNN(cudnnDestroyConvolutionDescriptor(convDesc));
  CHECK_CUDNN(cudnnDestroyFilterDescriptor(wDesc));
  CHECK_CUDNN(cudnnDestroyTensorDescriptor(xDesc));
  CHECK_CUDNN(cudnnDestroyTensorDescriptor(yDesc));
  CHECK_CUDNN(cudnnDestroy(handle));

  return 0;
}
EOF
	/usr/local/cuda/bin/nvcc -o /tmp/$$.out /tmp/$$.cu -lcudnn && /tmp/$$.out
	rm -rf /tmp/$$.*
}

mkv2mp4() {
	if [ $# == 0 ]; then
		echo "Usage: $0 input.mkv" >&2
		return
	fi
	ffmpeg -y -i "$1" -map 0 -c copy -c:s mov_text "`echo $1 | sed 's:\.mkv$:.mp4:gi'`"
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
		ps aux --no-headers | grep "$1" | sed '/grep/d' | awk '{print $2}' | xargs kill $2
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
	if [ $# == 0 ];then
		echo "Usage: norm_vol file.mp4 level=-20 output.mp4"
		return
	fi
	lvl="$2"
	if [ ! "$lvl" ]; then
		lvl="-20"
	fi
	out="$3"
	ffmpeg-normalize "$1" -o $$.mp4 -c:a aac -t $lvl -nt rms -f
	if [ "$out" ]; then
		mv $$.mp4 "$out"
	else
		mv $$.mp4 "$1"
	fi
}

shopt -s direxpand

# `less` can view archives directly (.tar.gz, .zip, etc.)
export LESSOPEN="| /usr/bin/lesspipe %s";
export LESSCLOSE="/usr/bin/lesspipe %s %s";

export PS1="\[\e]0;\u@\h: \w\a\]\[\e[1;35m\]\u\[\e[0m\]@\[\e[1;36m\]\H\[\e[0m\]:\[\e[1;32m\]\w\[\e[0m\]\[\e[1;32m\]$\[\e[0m\] "
