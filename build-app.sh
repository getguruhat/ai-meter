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
# A copy named with the version, which guruhat.com links to. The fixed name keeps
# releases/latest/download/AI-Meter-Installer.dmg working.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" AppInfo.plist)
cp "$ROOT/AI-Meter-Installer.dmg" "$ROOT/AI-Meter-$VERSION-Installer.dmg"
print "$APP"
