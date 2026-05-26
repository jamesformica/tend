#!/bin/bash
# Renders Resources/AppIcon.svg to a multi-resolution macOS iconset and bundles
# it into Resources/AppIcon.icns.
#
# Requires rsvg-convert (`brew install librsvg`) and iconutil (ships with macOS).

set -euo pipefail
cd "$(dirname "$0")/.."

SRC="tools/AppIcon.svg"
DST="Resources/AppIcon.icns"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "${ICONSET}"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "✗ rsvg-convert not found. Install with: brew install librsvg" >&2
    exit 1
fi

render() {
    local size="$1"
    local out="$2"
    rsvg-convert -w "${size}" -h "${size}" "${SRC}" -o "${ICONSET}/${out}"
}

render 16    icon_16x16.png
render 32    icon_16x16@2x.png
render 32    icon_32x32.png
render 64    icon_32x32@2x.png
render 128   icon_128x128.png
render 256   icon_128x128@2x.png
render 256   icon_256x256.png
render 512   icon_256x256@2x.png
render 512   icon_512x512.png
render 1024  icon_512x512@2x.png

iconutil -c icns "${ICONSET}" -o "${DST}"
rm -rf "${ICONSET}"

echo "✓ Built ${DST}"
