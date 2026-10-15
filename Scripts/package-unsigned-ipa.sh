#!/bin/bash
set -euo pipefail

ARCHIVE_DIR="${1:-build/Products/Release-iphoneos}"
APP_PATH="$ARCHIVE_DIR/CarLink.app"
OUT_DIR="${2:-build/ipa}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "CarLink.app não encontrado em: $APP_PATH" >&2
  exit 1
fi

rm -rf "$OUT_DIR" build/Payload
mkdir -p "$OUT_DIR" build/Payload
cp -R "$APP_PATH" build/Payload/

( cd build && /usr/bin/zip -qry "../$OUT_DIR/CarLink-unsigned.ipa" Payload )
rm -rf build/Payload

echo "IPA gerada: $OUT_DIR/CarLink-unsigned.ipa"
