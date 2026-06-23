# MOHT-specific configs
export ANTHROPIC_BASE_URL=http://10.8.0.9:9001
export ANTHROPIC_API_KEY=dummy
#export ANTHROPIC_AUTH_TOKEN=dummy
unset ANTHROPIC_AUTH_TOKEN
export DISABLE_AUTOUPDATER=1
export DISABLE_UPDATES=1
export ANTHROPIC_DEFAULT_OPUS_MODEL=comp9:Qwen3.6-35B-A3B
export ANTHROPIC_DEFAULT_SONNET_MODEL=comp9:Qwen3.6-35B-A3B
export ANTHROPIC_DEFAULT_HAIKU_MODEL=comp9:Qwen3.6-35B-A3B

if [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
	export GDK_BACKEND=x11
	export QT_QPA_PLATFORM=xcb
	unset WAYLAND_DISPLAY
fi

# Fish-like auto-completion
if [[ "$SHELL" =~ /bash ]]; then
	source /usr/local/ble-nightly/ble.sh --rcfile /etc/bash.blerc
fi

# General Linux Shortcuts
alias l='less'
alias ll='ls -al --color=auto'
alias lr='less -r'
alias t='top'
alias c='cat'
alias p='ps aux | less'
alias p8='ping 8.8.8.8'
alias pg='ping www.google.com.sg'
alias ac='zcat -f'
alias open=xdg-open
alias gtop="watch -n 1 \"nvidia-smi | grep '^| \{1,8\}[^ ]'\""
alias gtop="watch -n 1 \"nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,memory.used,memory.total | sed s:utilization:util:g; echo; ollama ps 2>/dev/null\""
alias killstop='kill $(jobs -p)'
alias git_gc_all='git reflog expire --expire=now --all && git gc --aggressive --prune=now'
alias sedm="sed -e '1h;2,\$H;\$!d;g' -e"
alias nv_run='DRI_PRIME=pci-0000_01_00_0 __VK_LAYER_NV_optimus=NVIDIA_only __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia'
alias megaraid_check='/opt/MegaRAID/MegaCli/MegaCli64 -LdPdInfo -a0'
alias sus="sudo -H env XAUTHORITY=$HOME/.Xauthority su"
alias sul='sudo -i'
alias ta='tmux a'
alias tls='tmux ls'
alias xp_start='xpra start :100  --start-child=xterm --start-via-proxy=no --opengl=yes'
alias xp_list='xpra list'
alias xp_stop='xpra stop :100'
alias xp_attach='xpra attach :100'

# multi-line sed
alias sedm="sed -e '1h;2,\$H;\$!d;g' -e"
alias py3="/opt/anaconda3/bin/python -i -c \"import os,sys,re,math,random;import pandas as pd;import numpy as np;from collections import *\""
alias apy="/opt/anaconda3/bin/python"
alias tf="PYTHONPATH=/opt/anaconda3/PYTHONPATH/tf"
alias test_pytorch="/opt/anaconda3/bin/python -c 'import torch;print(torch.cuda.is_available())'"

test_tensorflow() {
	if [[ "`uname -m`" == x86* ]]; then
		PYTHONPATH=/opt/anaconda3/PYTHONPATH/tf /opt/anaconda3/bin/python -c 'import tensorflow as tf; print(tf.test.is_gpu_available())'
	else
		docker run --gpus all -it --rm nvcr.io/nvidia/tensorflow:24.09-tf2-py3 python -c 'import tensorflow as tf; print(tf.test.is_gpu_available())'
	fi
}

test_tensorflow_full() {
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
	if [[ "`uname -m`" == x86* ]]; then
		PYTHONPATH=/opt/anaconda3/PYTHONPATH/tf /opt/anaconda3/bin/python -c "$pycode"
	else
		docker run --gpus all -it --rm -v /usr/share/datasets:/usr/share/datasets nvcr.io/nvidia/tensorflow:24.09-tf2-py3 python -c "$pycode"
	fi
}

test_pytorch_full()
{
    pycode="
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader
from tqdm import tqdm

print('PyTorch version:', torch.__version__)
print('CUDA available:', torch.cuda.is_available())
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print('Using device:', device)

with np.load('/usr/share/datasets/mnist.npz') as f:
    x_train, y_train = f['x_train'], f['y_train']
    x_test,  y_test  = f['x_test'],  f['y_test']

x_train = torch.tensor(x_train / 255.0, dtype=torch.float32)
x_test  = torch.tensor(x_test  / 255.0, dtype=torch.float32)
y_train = torch.tensor(y_train, dtype=torch.long)
y_test  = torch.tensor(y_test,  dtype=torch.long)

train_loader = DataLoader(TensorDataset(x_train, y_train), batch_size=128, shuffle=True)
test_loader  = DataLoader(TensorDataset(x_test, y_test), batch_size=1000)

model = nn.Sequential(
    nn.Flatten(),
    nn.Linear(28 * 28, 128),
    nn.ReLU(),
    nn.Dropout(0.2),
    nn.Linear(128, 10)
).to(device)

loss_fn = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters())

model.train()
for epoch in range(5):
    pbar = tqdm(train_loader, desc=f'Epoch {epoch + 1}/5', unit='batch')
    for xb, yb in pbar:
        xb, yb = xb.to(device), yb.to(device)
        optimizer.zero_grad()
        logits = model(xb)
        loss = loss_fn(logits, yb)
        loss.backward()
        optimizer.step()
        pbar.set_postfix(loss=f'{loss.item():.4f}')

model.eval()
correct = 0
total = 0
with torch.no_grad():
    for xb, yb in test_loader:
        xb, yb = xb.to(device), yb.to(device)
        logits = model(xb)
        pred = logits.argmax(dim=1)
        correct += (pred == yb).sum().item()
        total += yb.size(0)

print(f'Test accuracy: {correct / total:.4f}')

with torch.no_grad():
    probs = torch.softmax(model(x_test[:5].to(device)), dim=1)
    print(probs.cpu())
"
	/opt/anaconda3/bin/python -c "$pycode"
}

test_cudnn_profile() {
    /opt/anaconda3/bin/python <<'PY'
import torch
import torch.nn as nn
from torch.profiler import profile, ProfilerActivity

print("PyTorch version:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("cuDNN available:", torch.backends.cudnn.is_available())
print("cuDNN enabled:", torch.backends.cudnn.enabled)
print("cuDNN version:", torch.backends.cudnn.version())

if not torch.cuda.is_available():
    raise SystemExit("CUDA is not available.")

if not torch.backends.cudnn.is_available():
    raise SystemExit("cuDNN is not available in this PyTorch build.")

device = torch.device("cuda")
print("Using device:", device)
print("GPU:", torch.cuda.get_device_name(0))

torch.backends.cudnn.enabled = True
torch.backends.cudnn.benchmark = True
torch.backends.cudnn.deterministic = False

# Use a convolution workload large enough that PyTorch should prefer cuDNN.
model = nn.Sequential(
    nn.Conv2d(64, 128, kernel_size=3, padding=1),
    nn.ReLU(),
    nn.Conv2d(128, 128, kernel_size=3, padding=1),
    nn.ReLU(),
).to(device)

x = torch.randn(32, 64, 128, 128, device=device, requires_grad=True)

# Warm up CUDA/cuDNN.
for _ in range(10):
    y = model(x)
    loss = y.square().mean()
    loss.backward()
    model.zero_grad(set_to_none=True)
    x.grad = None

torch.cuda.synchronize()
print("Warm-up completed.")

with profile(
    activities=[ProfilerActivity.CPU, ProfilerActivity.CUDA],
    record_shapes=True,
    profile_memory=False,
    with_stack=False,
) as prof:
    y = model(x)
    loss = y.square().mean()
    loss.backward()
    torch.cuda.synchronize()

print()
print("=== Top profiler events by CUDA time ===")
print(prof.key_averages().table(sort_by="cuda_time_total", row_limit=40))

print()
print("=== Events containing 'cudnn' ===")
events = prof.key_averages()
cudnn_events = [e for e in events if "cudnn" in e.key.lower()]

if cudnn_events:
    for e in cudnn_events:
        cuda_ms = getattr(e, "cuda_time_total", 0) / 1000.0
        cpu_ms = getattr(e, "cpu_time_total", 0) / 1000.0
        print(f"{e.key:60s} calls={e.count:<4d} cpu={cpu_ms:.3f} ms cuda={cuda_ms:.3f} ms")
    print()
    print("Result: cuDNN-related profiler events were observed.")
else:
    print("No profiler event name contained 'cudnn'.")
    print("Result: this run did not visibly prove cuDNN usage.")
    print("Try a larger tensor, a different PyTorch version, or Nsight Systems if needed.")

PY
}

test_cudnn_full() 
{ 
    pycode="
import os
import time
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import TensorDataset, DataLoader
from tqdm import tqdm

print('PyTorch version:', torch.__version__)
print('CUDA available:', torch.cuda.is_available())
print('cuDNN available:', torch.backends.cudnn.is_available())
print('cuDNN enabled:', torch.backends.cudnn.enabled)
print('cuDNN version:', torch.backends.cudnn.version())

if not torch.cuda.is_available():
    print('CUDA is not available; cuDNN test cannot run on GPU.')
    raise SystemExit(0)

if not torch.backends.cudnn.is_available():
    print('cuDNN is not available in this PyTorch build.')
    raise SystemExit(0)

device = torch.device('cuda')
print('Using device:', device)
print('GPU:', torch.cuda.get_device_name(0))

torch.backends.cudnn.benchmark = True
print('cuDNN benchmark mode:', torch.backends.cudnn.benchmark)

with np.load('/usr/share/datasets/mnist.npz') as f:
    x_train, y_train = f['x_train'], f['y_train']
    x_test,  y_test  = f['x_test'],  f['y_test']

x_train = torch.tensor(x_train / 255.0, dtype=torch.float32).unsqueeze(1)
x_test  = torch.tensor(x_test  / 255.0, dtype=torch.float32).unsqueeze(1)
y_train = torch.tensor(y_train, dtype=torch.long)
y_test  = torch.tensor(y_test,  dtype=torch.long)

train_loader = DataLoader(
    TensorDataset(x_train, y_train),
    batch_size=128,
    shuffle=True,
    pin_memory=True
)

test_loader = DataLoader(
    TensorDataset(x_test, y_test),
    batch_size=1000,
    pin_memory=True
)

model = nn.Sequential(
    nn.Conv2d(1, 32, kernel_size=3, padding=1),
    nn.ReLU(),
    nn.MaxPool2d(2),

    nn.Conv2d(32, 64, kernel_size=3, padding=1),
    nn.ReLU(),
    nn.MaxPool2d(2),

    nn.Flatten(),
    nn.Linear(64 * 7 * 7, 128),
    nn.ReLU(),
    nn.Dropout(0.2),
    nn.Linear(128, 10)
).to(device)

loss_fn = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters())

# Warm-up pass to trigger CUDA/cuDNN initialization
model.train()
xb, yb = next(iter(train_loader))
xb, yb = xb.to(device, non_blocking=True), yb.to(device, non_blocking=True)
logits = model(xb)
loss = loss_fn(logits, yb)
loss.backward()
optimizer.step()
torch.cuda.synchronize()
print('Warm-up forward/backward pass completed.')

start = time.time()

for epoch in range(3):
    pbar = tqdm(train_loader, desc=f'Epoch {epoch + 1}/3', unit='batch')
    for xb, yb in pbar:
        xb = xb.to(device, non_blocking=True)
        yb = yb.to(device, non_blocking=True)

        optimizer.zero_grad(set_to_none=True)
        logits = model(xb)
        loss = loss_fn(logits, yb)
        loss.backward()
        optimizer.step()

        pbar.set_postfix(loss=f'{loss.item():.4f}')

torch.cuda.synchronize()
elapsed = time.time() - start
print(f'Training time: {elapsed:.2f} seconds')

model.eval()
correct = 0
total = 0

with torch.no_grad():
    for xb, yb in test_loader:
        xb = xb.to(device, non_blocking=True)
        yb = yb.to(device, non_blocking=True)

        logits = model(xb)
        pred = logits.argmax(dim=1)
        correct += (pred == yb).sum().item()
        total += yb.size(0)

print(f'Test accuracy: {correct / total:.4f}')

with torch.no_grad():
    probs = torch.softmax(model(x_test[:5].to(device)), dim=1)
    print(probs.cpu())

print('cuDNN convolution test completed successfully.')
";
    /opt/anaconda3/bin/python -c "$pycode"
}

test_nvcc(){
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
	/usr/local/cuda/bin/nvcc -o /tmp/$$.out /tmp/$$.cu && /usr/local/cuda/bin/nvprof /tmp/$$.out || /tmp/$$.out
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
	fi
	a="`ps aux`"
	echo "$a" | grep "$1" | awk '{print $2}' | xargs kill $2
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

vif() {
	if [ $# == 0 ]; then
		echo "Usage: $0 fullpath-to-the-file-to-edit"
		echo "This precreate the directory and edit the file using vim"
		return
	fi
	mkdir -p "`dirname \"$1\"`" && vi "$@"
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

if [ -s ~/anaconda3/bin/yt-dlp ]; then
	alias yd='~/anaconda3/bin/yt-dlp --embed-subs -R infinite --socket-timeout 3 --cookies-from-browser firefox:/home/xuancong/.mozilla/firefox/'
	alias ydvr='~/anaconda3/bin/yt-dlp -R infinite --socket-timeout 3 --user-agent "" --extractor-args "youtube:player-client=web"'
fi

shopt -s direxpand

# `less` can view archives directly (.tar.gz, .zip, etc.)
export LESSOPEN="| /usr/bin/lesspipe %s";
export LESSCLOSE="/usr/bin/lesspipe %s %s";

