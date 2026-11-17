#!/bin/bash
# Builds MacPulse.app (universal, ad-hoc signed) into ./build
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/MacPulse.app"
SDK="$(xcrun --show-sdk-path)"
DEPLOY_TARGET="13.0"
CACHE_DIR="${TMPDIR:-/tmp}/macpulse-module-cache"
mkdir -p "$CACHE_DIR"

# Sources live in Sources/ and Sources/Probes/, so collect them recursively.
SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(find "$ROOT/Sources" -name '*.swift' | sort)

echo "▸ Cleaning…"
rm -rf "$BUILD"
mkdir -p "$BUILD/bin" "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ Compiling arm64…"
swiftc -swift-version 5 -O -parse-as-library \
  -module-cache-path "$CACHE_DIR" \
  -Xcc -fmodules-cache-path="$CACHE_DIR" \
  -target "arm64-apple-macos${DEPLOY_TARGET}" \
  -sdk "$SDK" \
  -framework SwiftUI -framework AppKit -framework UserNotifications \
  "${SOURCES[@]}" \
  -o "$BUILD/bin/MacPulse-arm64"

BINARY="$BUILD/bin/MacPulse-arm64"

if swiftc -swift-version 5 -O -parse-as-library \
    -module-cache-path "$CACHE_DIR" \
    -Xcc -fmodules-cache-path="$CACHE_DIR" \
    -target "x86_64-apple-macos${DEPLOY_TARGET}" \
    -sdk "$SDK" \
    -framework SwiftUI -framework AppKit -framework UserNotifications \
    "${SOURCES[@]}" \
    -o "$BUILD/bin/MacPulse-x86_64" 2>/dev/null; then
  echo "▸ Building universal binary…"
  lipo -create "$BUILD/bin/MacPulse-arm64" "$BUILD/bin/MacPulse-x86_64" -output "$APP/Contents/MacOS/MacPulse"
else
  echo "▸ Intel slice unavailable, shipping arm64"
  cp "$BUILD/bin/MacPulse-arm64" "$APP/Contents/MacOS/MacPulse"
fi
chmod +x "$APP/Contents/MacOS/MacPulse"

echo "▸ Writing Info.plist…"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacPulse</string>
    <key>CFBundleDisplayName</key><string>MacPulse</string>
    <key>CFBundleIdentifier</key><string>com.macpulse.app</string>
    <key>CFBundleExecutable</key><string>MacPulse</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.3.0</string>
    <key>CFBundleVersion</key><string>5</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacPulse reads your login items so it can suggest removing ones you do not need.</string>
    <key>NSHumanReadableCopyright</key><string>MacPulse</string>
</dict>
</plist>
PLIST

echo "▸ Rendering icon…"
swiftc -O -module-cache-path "$CACHE_DIR" -Xcc -fmodules-cache-path="$CACHE_DIR" "$ROOT/Tools/MakeIcon.swift" -o "$BUILD/makeicon"
"$BUILD/makeicon" "$BUILD/icon-1024.png"
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16     "$BUILD/icon-1024.png" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$BUILD/icon-1024.png" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$BUILD/icon-1024.png" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$BUILD/icon-1024.png" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$BUILD/icon-1024.png" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$BUILD/icon-1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$BUILD/icon-1024.png" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$BUILD/icon-1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$BUILD/icon-1024.png" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$BUILD/icon-1024.png" "$ICONSET/icon_512x512@2x.png"
if ! iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
  python3 "$ROOT/Tools/pack-icns.py" "$ICONSET" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "▸ Signing (ad-hoc)…"
codesign --force --sign - --identifier com.macpulse.app "$APP" >/dev/null 2>&1 || true

echo "▸ Verifying…"
"$APP/Contents/MacOS/MacPulse" --check
echo
echo "✅ Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  echo "▸ Installing to /Applications…"
  osascript -e 'quit app "MacPulse"' >/dev/null 2>&1 || true
  sleep 1
  rm -rf /Applications/MacPulse.app
  cp -R "$APP" /Applications/
  open /Applications/MacPulse.app
  echo "✅ Installed and launched /Applications/MacPulse.app"
fi
