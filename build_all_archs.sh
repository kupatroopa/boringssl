#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SCRIPT_DIR="$PROJECT_ROOT/boringssl"
BUILD_SCRIPT="$SCRIPT_DIR/build_boring.sh"

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "build_boring.sh not found or not executable at $BUILD_SCRIPT" >&2
  exit 1
fi

ARCHS=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")

for arch in "${ARCHS[@]}"; do
  echo "\n=== Building BoringSSL for $arch ==="
  ANDROID_ABI="$arch" ENABLE_FIPS="${ENABLE_FIPS:-1}" ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-21}" "$BUILD_SCRIPT"
  echo "=== Completed $arch ===\n"
done

