#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/Possum.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Possum "$APP/Contents/MacOS/Possum"
cp scripts/Info.plist "$APP/Contents/Info.plist"
if [ -n "${VERSION:-}" ]; then
    VERSION="${VERSION#v}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
fi
cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "✅ Built $APP"
echo "   Run: open $APP"
