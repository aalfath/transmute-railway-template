#!/bin/bash
# Railway start script for Transmute. Sizes threads and workers from the
# container's cgroup limits (Railway shows the host's CPUs to processes),
# creates the first admin, then runs Transmute and exits non-zero if it stops
# on its own, so Railway's ON_FAILURE restart policy brings it back.
set -euo pipefail
cd /app

# --- CPU and memory limits from the cgroup ---------------------------------
cpus=1
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ "${period:-0}" -gt 0 ]; then
    cpus=$(( (quota + period - 1) / period ))
  else
    cpus=$(nproc)
  fi
fi
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 8 ] && cpus=8
mem_mb=0
if [ -r /sys/fs/cgroup/memory.max ]; then
  m=$(cat /sys/fs/cgroup/memory.max)
  [ "$m" != "max" ] && mem_mb=$(( m / 1048576 ))
fi
small=0
if [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 1536 ]; then small=1; fi

# Thread pools: Python, numpy/OpenBLAS, onnxruntime/OpenMP, tesseract, ffmpeg.
export PYTHON_CPU_COUNT="${PYTHON_CPU_COUNT:-$cpus}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$cpus}"
export OMP_THREAD_LIMIT="${OMP_THREAD_LIMIT:-$cpus}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-$cpus}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-$cpus}"
export NUMEXPR_MAX_THREADS="${NUMEXPR_MAX_THREADS:-$cpus}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
# onnxruntime (pymupdf-layout) threads, applied by sitecustomize.py.
export ORT_INTRA_OP_THREADS="${ORT_INTRA_OP_THREADS:-$cpus}"
# Run converter jobs through /railway/oomwrap (see sitecustomize.py).
export TRANSMUTE_OOM_WRAP="${TRANSMUTE_OOM_WRAP:-1}"
if [ "$small" = 1 ]; then
  workers=1
  export TRANSMUTE_FFMPEG_THREADS="${TRANSMUTE_FFMPEG_THREADS:-1}"
  # x264 lookahead and libvpx lag buffers hold whole frames: 1080p VP9 peaked at
  # ~400 MB with defaults, ~290 MB with these (other encoders ignore them).
  export TRANSMUTE_FFMPEG_EXTRA="${TRANSMUTE_FFMPEG_EXTRA:--rc-lookahead 10 -lag-in-frames 0}"
else
  workers=$cpus; [ "$workers" -gt 5 ] && workers=5
  export TRANSMUTE_FFMPEG_THREADS="${TRANSMUTE_FFMPEG_THREADS:-$cpus}"
fi
export CONVERSION_WORKER_CONCURRENCY="${CONVERSION_WORKER_CONCURRENCY:-$workers}"
export COMPRESSION_WORKER_CONCURRENCY="${COMPRESSION_WORKER_CONCURRENCY:-$workers}"
echo "[railway] cpus=$cpus mem_mb=${mem_mb:-unknown} workers=$CONVERSION_WORKER_CONCURRENCY/$COMPRESSION_WORKER_CONCURRENCY ffmpeg_threads=$TRANSMUTE_FFMPEG_THREADS"

# --- Settings ----------------------------------------------------------------
export PORT="${PORT:-3313}"
if [ -z "${AUTH_SECRET_KEY:-}" ]; then
  # Upstream would make a new random key on every boot and log everyone out.
  # Keep one on the volume instead.
  mkdir -p /app/data
  [ -s /app/data/.auth_secret_key ] || python -c 'import secrets;print(secrets.token_urlsafe(64))' > /app/data/.auth_secret_key
  AUTH_SECRET_KEY="$(cat /app/data/.auth_secret_key)"
  export AUTH_SECRET_KEY
fi
if [ -z "${APP_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

# --- First admin (before the URL answers) ------------------------------------
python /railway/bootstrap_admin.py

# --- Run ---------------------------------------------------------------------
Xvfb :99 -screen 0 1024x768x24 >/dev/null 2>&1 &
export DISPLAY=:99

stopping=0
python backend/main.py &
app=$!
trap 'stopping=1; kill -TERM "$app" 2>/dev/null || true' TERM INT
set +e
wait "$app"; rc=$?
# wait returns early when a trapped signal arrives; wait for the app itself.
while kill -0 "$app" 2>/dev/null; do wait "$app"; rc=$?; done
set -e
if [ "$stopping" = 1 ]; then exit 0; fi
echo "[railway] Transmute exited unexpectedly (code $rc)" >&2
[ "$rc" -eq 0 ] && rc=1
exit "$rc"
