#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
zsh scripts/generate-app-icon.sh
swift build -c release
APP="${PWD}/dist/Looma.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Looma "$APP/Contents/MacOS/Looma"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
mkdir -p "$APP/Contents/Resources/AgentIcons"
cp Resources/AgentIcons/* "$APP/Contents/Resources/AgentIcons/"
echo "Built: $APP"
