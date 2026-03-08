#!/bin/bash
# DxaiBar .app 번들 빌드 스크립트
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DXAI_ROOT="$(dirname "$(dirname "$PROJECT_DIR")")"

BUILD_CONFIG="${1:-release}"
APP_NAME="DxaiBar"
BUNDLE_ID="com.dxai.DxaiBar"
VERSION="${DXAI_VERSION:-1.0.0}"

# Output paths
if [[ "$BUILD_CONFIG" == "release" ]]; then
    BUILD_FLAGS="-c release"
else
    BUILD_FLAGS=""
fi

echo "Building $APP_NAME ($BUILD_CONFIG)..."
cd "$PROJECT_DIR"
swift build $BUILD_FLAGS 2>&1

# Find built executable
if [[ "$BUILD_CONFIG" == "release" ]]; then
    EXEC_PATH="$(swift build $BUILD_FLAGS --show-bin-path)/$APP_NAME"
else
    EXEC_PATH="$(swift build --show-bin-path)/$APP_NAME"
fi

if [[ ! -f "$EXEC_PATH" ]]; then
    echo "Error: executable not found at $EXEC_PATH"
    exit 1
fi

# Create .app bundle
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp "$EXEC_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Generate Info.plist with current version
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Deus eX AI</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# PkgInfo
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Ad-hoc code sign
codesign -s - --force --deep "$APP_DIR" 2> /dev/null || true

echo ""
echo "Built: $APP_DIR"
echo "Size: $(du -sh "$APP_DIR" | cut -f1)"

# Verify bundle
if /usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_DIR/Contents/Info.plist" > /dev/null 2>&1; then
    echo "Bundle ID: $BUNDLE_ID"
    echo "Version: $VERSION"
else
    echo "Warning: Info.plist verification failed"
    exit 1
fi

# Create distributable zip
ZIP_PATH="$PROJECT_DIR/build/$APP_NAME.zip"
rm -f "$ZIP_PATH"
cd "$PROJECT_DIR/build"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"
echo "Zip: $ZIP_PATH ($(du -sh "$ZIP_PATH" | cut -f1))"
