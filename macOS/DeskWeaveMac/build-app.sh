#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/.build"
STAGING_DIR="$(mktemp -d /tmp/deskweave-app.XXXXXX)"
APP_DIR="$STAGING_DIR/DeskWeave.app"
OUTPUT_APP_DIR="$PROJECT_DIR/dist/DeskWeave.app"
CONTENTS_DIR="$APP_DIR/Contents"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"

cd "$PROJECT_DIR"
mkdir -p "$MODULE_CACHE_DIR"
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR" \
    swift build -c release --scratch-path "$BUILD_DIR" --disable-sandbox --jobs 1

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BUILD_DIR/release/DeskWeaveMac" "$CONTENTS_DIR/MacOS/DeskWeaveMac"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
xattr -cr "$APP_DIR"
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$CONTENTS_DIR/Info.plist")
DESIGNATED_REQUIREMENT="=designated => identifier \"$BUNDLE_ID\""
codesign \
    --force \
    --deep \
    --sign - \
    --requirements "$DESIGNATED_REQUIREMENT" \
    "$APP_DIR"
# Documents may be backed by a File Provider that reattaches Finder metadata
# immediately after signing. These attributes are not part of the app and make
# strict signature verification fail, so remove only those bundle attributes.
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true

mkdir -p "$PROJECT_DIR/dist"
ditto "$APP_DIR" "$OUTPUT_APP_DIR"
xattr -d com.apple.FinderInfo "$OUTPUT_APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$OUTPUT_APP_DIR" 2>/dev/null || true

echo "$OUTPUT_APP_DIR"
