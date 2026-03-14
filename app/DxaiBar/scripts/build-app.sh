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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

# Bundle CLI + support files
CLI_SCRIPT="$DXAI_ROOT/dxai"
if [[ -f "$CLI_SCRIPT" ]]; then
    # CLI entrypoint at Resources root (SCRIPT_DIR = Resources/)
    cp "$CLI_SCRIPT" "$APP_DIR/Contents/Resources/dxai"
    chmod +x "$APP_DIR/Contents/Resources/dxai"
    # Copy support dirs
    for dir in bin lib conf; do
        if [[ -d "$DXAI_ROOT/$dir" ]]; then
            cp -R "$DXAI_ROOT/$dir" "$APP_DIR/Contents/Resources/$dir"
        fi
    done
    echo "CLI bundled into app"
fi

# App icon
ICONSET_DIR="$PROJECT_DIR/Sources/Assets.xcassets/AppIcon.appiconset"
if [[ -d "$ICONSET_DIR" ]]; then
    ICON_1024="$ICONSET_DIR/icon_1024x1024.png"
    if [[ -f "$ICON_1024" ]]; then
        ICNS_PATH="$APP_DIR/Contents/Resources/AppIcon.icns"
        ICONSET_TMP=$(mktemp -d)/AppIcon.iconset
        mkdir -p "$ICONSET_TMP"
        sips -z 16 16     "$ICON_1024" --out "$ICONSET_TMP/icon_16x16.png"      > /dev/null 2>&1
        sips -z 32 32     "$ICON_1024" --out "$ICONSET_TMP/icon_16x16@2x.png"   > /dev/null 2>&1
        sips -z 32 32     "$ICON_1024" --out "$ICONSET_TMP/icon_32x32.png"      > /dev/null 2>&1
        sips -z 64 64     "$ICON_1024" --out "$ICONSET_TMP/icon_32x32@2x.png"   > /dev/null 2>&1
        sips -z 128 128   "$ICON_1024" --out "$ICONSET_TMP/icon_128x128.png"    > /dev/null 2>&1
        sips -z 256 256   "$ICON_1024" --out "$ICONSET_TMP/icon_128x128@2x.png" > /dev/null 2>&1
        sips -z 256 256   "$ICON_1024" --out "$ICONSET_TMP/icon_256x256.png"    > /dev/null 2>&1
        sips -z 512 512   "$ICON_1024" --out "$ICONSET_TMP/icon_256x256@2x.png" > /dev/null 2>&1
        sips -z 512 512   "$ICON_1024" --out "$ICONSET_TMP/icon_512x512.png"    > /dev/null 2>&1
        cp "$ICON_1024"                      "$ICONSET_TMP/icon_512x512@2x.png"
        iconutil -c icns -o "$ICNS_PATH" "$ICONSET_TMP"
        rm -rf "$(dirname "$ICONSET_TMP")"
        echo "App icon bundled"
    fi
fi

# PkgInfo
printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Code signing
SIGN_IDENTITY="Developer ID Application: JEONGHUN LEE (Y6DMY4SBGN)"
TEAM_ID="Y6DMY4SBGN"

# Entitlements for hardened runtime
ENTITLEMENTS="$PROJECT_DIR/build/entitlements.plist"
cat > "$ENTITLEMENTS" << 'ENTPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
ENTPLIST

if security find-identity -v -p codesigning | grep -q "$TEAM_ID"; then
    echo "Signing with Developer ID..."
    # Sign all embedded binaries first (inside-out)
    find "$APP_DIR/Contents/Resources" -type f -perm +111 | while read -r bin; do
        if file "$bin" | grep -q "Mach-O"; then
            echo "  Signing: $(basename "$bin")"
            codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
                --sign "$SIGN_IDENTITY" --timestamp "$bin"
        fi
    done
    # Sign main executable
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" --timestamp \
        "$APP_DIR/Contents/MacOS/$APP_NAME"
    # Sign the app bundle
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
        --sign "$SIGN_IDENTITY" --timestamp \
        "$APP_DIR"
    codesign --verify --deep --strict "$APP_DIR"
    echo "Code signing verified"
else
    echo "Developer ID not found, using ad-hoc signing..."
    codesign -s - --force --deep "$APP_DIR" 2> /dev/null || true
fi
rm -f "$ENTITLEMENTS"

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

# Notarization
if security find-identity -v -p codesigning | grep -q "$TEAM_ID"; then
    echo ""
    echo "Submitting for notarization..."
    if xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "glen15@naver.com" \
        --team-id "$TEAM_ID" \
        --keychain-profile "dxai-notary" \
        --wait; then
        echo "Notarization succeeded, stapling..."
        xcrun stapler staple "$APP_DIR"
        # Re-create zip with stapled app
        rm -f "$ZIP_PATH"
        ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"
        echo "Stapled zip: $ZIP_PATH ($(du -sh "$ZIP_PATH" | cut -f1))"
    else
        echo "Warning: Notarization failed. App is signed but not notarized."
    fi
fi
