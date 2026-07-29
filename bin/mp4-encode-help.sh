#!/bin/bash

echo '
To encode a video using H265 with GPU support:
ffmpeg -hwaccel cuda -hwaccel_output_format cuda -i input.mp4 -c:v hevc_nvenc -cq 28 -preset slow -c:a copy output.mp4


## Hardware Encoder Flag Mapping

| GPU Hardware / Platform | Video Codec Flag (-c:v) | Quality Control Flag | Recommended Value Range | Speed/Preset Flag |
|---|---|---|---|---|
| NVIDIA GeForce / Quadro | hevc_nvenc | -cq | 24 (High) to 30 (Low size) | -preset slow |
| Apple Silicon (M1/M2/M3/M4) | hevc_videotoolbox | -q:v | 50 (Low size) to 80 (High) | N/A |
| AMD Radeon (Windows) | hevc_amf | -rc:v cbr or -qp | 22 (High) to 28 (Low size) | N/A |
| AMD / Intel (Linux VA-API) | hevc_vaapi | -global_quality | 25 (High) to 32 (Low size) | N/A |
| Intel Quick Sync (QSV) | hevc_qsv | -global_quality | 24 (High) to 30 (Low size) | -preset slow |


## Critical Compression Adjustments

* Constant Rate Factor (-crf) Warning: Hardware GPU encoders do not support the standard software -crf flag. You must use -cq, -qp, or -global_quality depending on your card architecture.
* The Preset Flag: For NVIDIA (hevc_nvenc), using -preset slow or -preset p6 delivers the tightest compression profile and smallest file sizes without compromising processing throughput.
'

