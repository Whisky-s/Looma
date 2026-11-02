#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

SOURCE="Resources/AppIcon/AppIcon.png"
ICONSET="Resources/AppIcon/AppIcon.iconset"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -s format png -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon/AppIcon.icns
