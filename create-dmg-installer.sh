#!/bin/zsh
# Build a Finder-friendly macOS installer disk image: drag the app to Applications.
set -euo pipefail

if (( $# != 3 )); then
  print -u2 "usage: $0 <app bundle> <volume name> <output dmg>"
  exit 64
fi

APP_BUNDLE="${1:A}"
VOLUME_NAME="$2"
OUTPUT_DMG="${3:A}"
APP_NAME="${APP_BUNDLE:t}"

if [[ ! -d "$APP_BUNDLE" || "${APP_NAME:e}" != "app" ]]; then
  print -u2 "Expected an existing .app bundle, got: $APP_BUNDLE"
  exit 66
fi

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/guruhat-dmg.XXXXXX")
STAGING_DIR="$WORK_DIR/staging"
RW_DMG="$WORK_DIR/installer-rw.dmg"
MOUNT_DIR=""
ATTACH_INFO="$WORK_DIR/attach.plist"
cleanup() {
  # `mount` canonicalizes /var to /private/var, so asking hdiutil directly is
  # more reliable than trying to match the mount table.
  [[ -z "$MOUNT_DIR" ]] || hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIR" "${OUTPUT_DMG:h}"
ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$OUTPUT_DMG"
hdiutil create -quiet -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -format UDRW -ov "$RW_DMG"
# Finder needs to see the volume while saving its window state. The finished
# image will still open normally for the person installing the app.
hdiutil attach -plist "$RW_DMG" > "$ATTACH_INFO"
MOUNT_DIR=$(/usr/libexec/PlistBuddy -c 'Print :system-entities' "$ATTACH_INFO" | /usr/bin/awk -F' = ' '/mount-point =/{ print $2; exit }')
if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
  print -u2 "Unable to determine the mounted installer volume."
  exit 74
fi

# Save the same uncluttered icon view in the disk image that users see on open.
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        # Reference: 1160 x 768 pixels on a 2x Retina display (580 x 384 points).
        set bounds of container window to {200, 200, 780, 584}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        # Finder display size only; the app icon files themselves are never altered.
        set icon size of viewOptions to 192
        set text size of viewOptions to 14
        set background color of viewOptions to {65535, 65535, 65535}
        # Two evenly spaced icon centers, with room for labels below.
        set position of item "$APP_NAME" of container window to {155, 118}
        set position of item "Applications" of container window to {425, 118}
        update without registering applications
        delay 2
        close
        delay 2
    end tell
end tell
APPLESCRIPT

hdiutil detach "$MOUNT_DIR" -quiet
hdiutil convert -quiet "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG"
print "$OUTPUT_DMG"
