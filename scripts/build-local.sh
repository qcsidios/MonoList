#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MonoList"
APP_VERSION="${MONOLIST_APP_VERSION:-v0.1.0}"
BUNDLE_SHORT_VERSION="${APP_VERSION#v}"
APP_BUILD="${MONOLIST_APP_BUILD:-1}"
MIN_MACOS_VERSION="14.0"
SWIFT_TARGET="arm64-apple-macosx$MIN_MACOS_VERSION"
BUILD_DIR="$ROOT_DIR/build/local"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/$APP_NAME"
CODESIGN_IDENTITY="${MONOLIST_CODESIGN_IDENTITY:-}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

SWIFT_SOURCES=()
while IFS= read -r source_file; do
  SWIFT_SOURCES+=("$source_file")
done < <(find "$ROOT_DIR/MonoList" -name '*.swift' | sort)

swiftc \
  -O \
  -target "$SWIFT_TARGET" \
  "${SWIFT_SOURCES[@]}" \
  -o "$EXECUTABLE"

ICON_PLIST=""
if [[ -f "$ROOT_DIR/MonoList/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/MonoList/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
  ICON_PLIST=$'    <key>CFBundleIconFile</key>\\n    <string>AppIcon.icns</string>'
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleDisplayName</key>
    <string>MonoList</string>
    <key>CFBundleExecutable</key>
    <string>MonoList</string>
$ICON_PLIST
    <key>CFBundleIdentifier</key>
    <string>com.qingcheng.monolist.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MonoList</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$BUNDLE_SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS_VERSION</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
chmod +x "$EXECUTABLE"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_DIR" >/dev/null
else
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
