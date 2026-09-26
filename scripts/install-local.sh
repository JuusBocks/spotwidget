#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/build/DerivedData"
CONFIGURATION="${CONFIGURATION:-Debug}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"

usage() {
  cat <<'USAGE'
Usage: ./scripts/install-local.sh [--team-id TEAM_ID] [--release]

Builds Widgify with Xcode, installs it into /Applications, registers the
widget extension, refreshes WidgetKit, and opens the menu bar helper.

Options:
  --team-id TEAM_ID   Apple Developer Team ID. Optional after signing is
                      already configured in Xcode.
  --release           Build the Release configuration instead of Debug.
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
    --release)
      CONFIGURATION="Release"
      shift
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

XCODEBUILD_ARGS=(
  -project "$ROOT_DIR/SpotifyWidgetMac.xcodeproj"
  -scheme SpotifyWidgetMac
  -configuration "$CONFIGURATION"
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -allowProvisioningUpdates
  build
)

if [[ -n "$TEAM_ID" ]]; then
  XCODEBUILD_ARGS+=(DEVELOPMENT_TEAM="$TEAM_ID")
fi

echo "Building Widgify..."
xcodebuild "${XCODEBUILD_ARGS[@]}"

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Widgify.app"
INSTALL_APP="/Applications/Widgify.app"
WIDGET_APP="$INSTALL_APP/Contents/PlugIns/SpotifyWidgetExtension.appex"

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Build finished, but Widgify.app was not found at $BUILT_APP" >&2
  exit 1
fi

echo "Installing Widgify into /Applications..."
pkill -f "$INSTALL_APP" >/dev/null 2>&1 || true
rm -rf "$INSTALL_APP"
cp -R "$BUILT_APP" /Applications/

echo "Registering the widget extension..."
pluginkit -a "$WIDGET_APP" >/dev/null 2>&1 || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f -R -trusted "$INSTALL_APP"

echo "Refreshing WidgetKit..."
killall chronod >/dev/null 2>&1 || true

echo "Opening Widgify..."
open "$INSTALL_APP"

cat <<'DONE'

Widgify is installed.

To add it:
1. Control-click the desktop.
2. Choose Edit Widgets.
3. Search for Widgify.
4. Drag it to the desktop.

If macOS asks for Automation access, allow Widgify to control Spotify.
DONE
