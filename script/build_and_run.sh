#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
CONFIGURATION="${SCANSPLIT_CONFIGURATION:-debug}"
APP_NAME="ScanSplit"
BUNDLE_ID="local.tom.scansplit"
APP_BUNDLE="${SCANSPLIT_APP_BUNDLE:-$ROOT_DIR/dist/$APP_NAME.app}"
if [[ "$MODE" != "--build-only" ]]; then pkill -x "$APP_NAME" >/dev/null 2>&1 || true; fi
swift build -c "$CONFIGURATION"
BUILD_BINARY="$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ScanSplit</string>
<key>CFBundleIdentifier</key><string>local.tom.scansplit</string>
<key>CFBundleName</key><string>ScanSplit</string>
<key>CFBundleDisplayName</key><string>ScanSplit</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>PDF Document</string>
<key>LSItemContentTypes</key><array><string>com.adobe.pdf</string></array>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Alternate</string>
</dict></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP_BUNDLE"
case "$MODE" in
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --build-only) printf '%s\n' "$APP_BUNDLE" ;;
  --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "ScanSplit"' ;;
  --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.tom.scansplit"' ;;
  *) printf 'usage: %s [run|--build-only|--verify|--debug|--logs|--telemetry]\n' "$0" >&2; exit 2 ;;
esac
