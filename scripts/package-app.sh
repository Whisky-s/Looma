#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
zsh scripts/build-app.sh
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/intel
APP="${PWD}/dist/Looma.app"
ARM_BINARY=$(swift build -c release --show-bin-path)
INTEL_BINARY=$(swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/intel --show-bin-path)
lipo -create "$ARM_BINARY/Looma" "$INTEL_BINARY/Looma" -output "$APP/Contents/MacOS/Looma"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/looma-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Looma.app"
ln -s /Applications "$STAGING/Applications"
cp docs/Looma-安装说明.txt "$STAGING/安装说明.txt"
DMG="${PWD}/dist/Looma-macOS-Universal-$(date +%Y%m%d).dmg"
hdiutil create -volname Looma -srcfolder "$STAGING" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"
lipo -archs "$APP/Contents/MacOS/Looma"
echo "Packaged: $DMG"
