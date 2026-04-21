#!/usr/bin/env bash
# Build the Lambda deployment package: installs deps into build/pkg/ and zips it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$HERE/build"
PKG_DIR="$BUILD_DIR/pkg"
ZIP_PATH="$BUILD_DIR/document_processor.zip"
PYTHON_BIN="${PYTHON_BIN:-python3}"

rm -rf "$BUILD_DIR"
mkdir -p "$PKG_DIR"

# Deps first (into pkg/), then source on top so handler.py sits at the zip root.
# Force Linux x86_64 wheels so native bindings (e.g. orjson) match the Lambda runtime,
# otherwise a host build on macOS/ARM would ship incompatible .so files.
"$PYTHON_BIN" -m pip install \
  --quiet \
  --upgrade \
  --target "$PKG_DIR" \
  --platform manylinux2014_x86_64 \
  --python-version 3.12 \
  --implementation cp \
  --only-binary=:all: \
  -r "$HERE/requirements.txt"

cp "$HERE/handler.py" "$PKG_DIR/"

# Strip junk that bloats the zip without changing behavior.
find "$PKG_DIR" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "$PKG_DIR" -type d -name "*.dist-info" -prune -exec rm -rf {} +
find "$PKG_DIR" -type d -name "tests" -prune -exec rm -rf {} +

(cd "$PKG_DIR" && zip -qr "$ZIP_PATH" .)

echo "built $ZIP_PATH ($(du -h "$ZIP_PATH" | cut -f1))"
