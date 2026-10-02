#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
VERSION="${VERSION:-}"
DIST_DIR="$ROOT_DIR/dist"
DMG_VOLUME_NAME="SpotWidget"

usage() {
  cat <<'USAGE'
Usage: ./scripts/package-app.sh [--team-id TEAM_ID] [--debug] [--version VERSION]

Builds SpotWidget and creates downloadable zip and dmg packages in dist/.

Options:
  --team-id TEAM_ID   Apple Developer Team ID. Optional after signing is
                      already configured in Xcode.
  --debug             Package a Debug build instead of Release.
  --version VERSION   Version label for the zip filename.
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      TEAM_ID="${2:-}"
      if [[ -z "$TEAM_ID" ]]; then
        echo "Missing value for --team-id" >&2
        exit 2
      fi
      shift 2
      ;;
    --debug)
      CONFIGURATION="Debug"
      shift
      ;;
    --version)
      VERSION="${2:-}"
      if [[ -z "$VERSION" ]]; then
        echo "Missing value for --version" >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild was not found. Install Xcode from the Mac App Store first." >&2
  exit 1
fi

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist" 2>/dev/null || true)"
fi

if [[ "$VERSION" == *'$('* ]]; then
  VERSION=""
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(awk -F' = ' '/MARKETING_VERSION/ { gsub(/;/, "", $2); print $2; exit }' "$ROOT_DIR/SpotWidget.xcodeproj/project.pbxproj")"
fi

if [[ -z "$VERSION" ]]; then
  VERSION="local"
fi

XCODEBUILD_ARGS=(
  -project "$ROOT_DIR/SpotWidget.xcodeproj"
  -scheme SpotWidget
  -configuration "$CONFIGURATION"
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -allowProvisioningUpdates
  build
)

if [[ -n "$TEAM_ID" ]]; then
  XCODEBUILD_ARGS+=(DEVELOPMENT_TEAM="$TEAM_ID")
fi

echo "Building SpotWidget $CONFIGURATION..."
xcodebuild "${XCODEBUILD_ARGS[@]}"

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/SpotWidget.app"
ZIP_PATH="$DIST_DIR/SpotWidget-$VERSION-macOS.zip"
SHA_PATH="$ZIP_PATH.sha256"
DMG_STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/SpotWidget-$VERSION-macOS.dmg"
DMG_SHA_PATH="$DMG_PATH.sha256"

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Build finished, but SpotWidget.app was not found at $BUILT_APP" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$DMG_STAGING_DIR"
rm -f "$ZIP_PATH" "$SHA_PATH" "$DMG_PATH" "$DMG_SHA_PATH"

echo "Creating $ZIP_PATH..."
ditto -c -k --sequesterRsrc --keepParent "$BUILT_APP" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | tee "$SHA_PATH"

echo "Creating $DMG_PATH..."
mkdir -p "$DMG_STAGING_DIR"
cp -R "$BUILT_APP" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/→ Applications - drag SpotWidget here"
cat > "$DMG_STAGING_DIR/READ ME - Next Steps.txt" <<'STEPS'
Install SpotWidget

1. Drag SpotWidget.app onto "→ Applications - drag SpotWidget here".
2. Open SpotWidget from Applications.
3. Use Privacy & Security > Open Anyway if macOS blocks it.
4. Add SpotWidget from desktop widgets.
5. Play Spotify and use the widget.
STEPS

hdiutil create \
  -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
shasum -a 256 "$DMG_PATH" | tee "$DMG_SHA_PATH"
rm -rf "$DMG_STAGING_DIR"

cat <<DONE

Created:
  $ZIP_PATH
  $SHA_PATH
  $DMG_PATH
  $DMG_SHA_PATH

Upload the dmg to a GitHub Release for the familiar drag-and-drop install.
For wider distribution, sign with Developer ID and notarize before shipping.
DONE
