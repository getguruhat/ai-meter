#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"
swift build -c release

APP="$ROOT/AI Meter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AIMeter "$APP/Contents/MacOS/AIMeter"
cp AppInfo.plist "$APP/Contents/Info.plist"
cp icon.png "$APP/Contents/Resources/icon.png"
codesign --force --deep --sign - "$APP" >/dev/null

"$ROOT/create-dmg-installer.sh" "$APP" "AI Meter" "$ROOT/AI-Meter-Installer.dmg"
print "$APP"
