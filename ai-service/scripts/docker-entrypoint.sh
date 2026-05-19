#!/bin/sh
set -eu

ensure_writable_dir() {
  dir="$1"
  mkdir -p "$dir"
  chmod 0777 "$dir" 2>/dev/null || true
}

ensure_writable_dir "${LOCAL_IMAGE_ROOT:-/data/images}"
ensure_writable_dir "${PRODUCT_IMAGE_DIR:-/data/images/products}"
ensure_writable_dir "${ROOM_UPLOAD_DIR:-/data/images/rooms}"
ensure_writable_dir "${GENERATED_IMAGE_DIR:-/data/images/generated}"

exec "$@"
