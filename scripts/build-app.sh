#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Widgify.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLUGINS_DIR="$CONTENTS_DIR/PlugIns"
WIDGET_DIR="$PLUGINS_DIR/WidgifyExtension.appex"
WIDGET_CONTENTS_DIR="$WIDGET_DIR/Contents"
WIDGET_MACOS_DIR="$WIDGET_CONTENTS_DIR/MacOS"
SDKROOT="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/module-cache}"

export SDKROOT
export CLANG_MODULE_CACHE_PATH

cd "$ROOT_DIR"
swift build -c release -Xswiftc -sdk -Xswiftc "$SDKROOT"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$WIDGET_MACOS_DIR"
cp ".build/release/Widgify" "$MACOS_DIR/Widgify"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

cp ".build/release/WidgifyExtension" "$WIDGET_MACOS_DIR/WidgifyExtension"
cp "Resources/WidgetExtensionInfo.plist" "$WIDGET_CONTENTS_DIR/Info.plist"

WIDGET_OBJECTS_DIR="$ROOT_DIR/.build/out/Intermediates.noindex/Widgify.build/Release/WidgifyExtension-p.build/Objects-normal/arm64"
METADATA_ROOT="$ROOT_DIR/.build/Metadata.appintents"
SOURCE_LIST="$ROOT_DIR/.build/widget-sources.txt"
CONST_VALUES_LIST="$ROOT_DIR/.build/widget-const-values.txt"

printf '%s\n' "$ROOT_DIR"/Sources/WidgifyExtension/*.swift > "$SOURCE_LIST"
printf '%s\n' "$WIDGET_OBJECTS_DIR/WidgifyExtension-primary.swiftconstvalues" > "$CONST_VALUES_LIST"
rm -rf "$METADATA_ROOT"

/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor \
  --output "$METADATA_ROOT" \
  --toolchain-dir /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain \
  --module-name WidgifyExtension \
  --sdk-root "$SDKROOT" \
  --xcode-version 17C52 \
  --platform-family macOS \
  --deployment-target 14.0 \
  --target-triple arm64-apple-macos14.0 \
  --source-file-list "$SOURCE_LIST" \
  --swift-const-vals-list "$CONST_VALUES_LIST" \
  --force \
  --force-metadata-output

mkdir -p "$WIDGET_CONTENTS_DIR/Resources"
cp -R "$METADATA_ROOT/Metadata.appintents" "$WIDGET_CONTENTS_DIR/Resources/Metadata.appintents"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - --entitlements "$ROOT_DIR/Resources/WidgetExtension.entitlements" "$WIDGET_DIR" >/dev/null
  codesign --force --sign - --entitlements "$ROOT_DIR/Resources/App.entitlements" "$APP_DIR" >/dev/null
fi

echo "Built: $APP_DIR"
