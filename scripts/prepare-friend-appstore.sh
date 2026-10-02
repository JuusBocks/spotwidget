#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/SpotWidget.xcodeproj/project.pbxproj"
APP_INFO="$ROOT_DIR/Resources/Info.plist"
WIDGET_INFO="$ROOT_DIR/Resources/WidgetExtensionInfo.plist"

APP_NAME="${APP_NAME:-SpotWidget}"
APP_BUNDLE_ID=""
TEAM_ID=""

usage() {
  cat <<'USAGE'
Usage: ./scripts/prepare-friend-appstore.sh --team-id TEAM_ID --bundle-id APP_BUNDLE_ID [--app-name NAME]

Prepares the local Xcode project to upload SpotWidget from another
Apple Developer account.

Required:
  --team-id     Friend's Apple Developer Team ID, for example ABC123XYZ9.
  --bundle-id   New app bundle ID owned by that team, for example
                com.friendname.SpotWidget.

Optional:
  --app-name    Installed app/widget display name. Defaults to SpotWidget.

This updates:
  - Main app bundle ID.
  - Widget extension bundle ID.
  - Xcode development team.
  - Bundle URL name.
  - App and widget display names.

It does not change source behavior, the spotwidget:// URL scheme, or playback logic.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      TEAM_ID="${2:-}"
      shift 2
      ;;
    --bundle-id)
      APP_BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --app-name)
      APP_NAME="${2:-}"
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

if [[ -z "$TEAM_ID" || -z "$APP_BUNDLE_ID" ]]; then
  echo "Missing --team-id or --bundle-id." >&2
  usage
  exit 2
fi

if [[ ! "$APP_BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+[A-Za-z0-9]$ ]]; then
  echo "Bundle ID looks invalid: $APP_BUNDLE_ID" >&2
  exit 2
fi

EXTENSION_BUNDLE_ID="$APP_BUNDLE_ID.SpotWidgetExtension"
BACKUP_DIR="$ROOT_DIR/.build/appstore-switch-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$PROJECT_FILE" "$BACKUP_DIR/project.pbxproj"
cp "$APP_INFO" "$BACKUP_DIR/Info.plist"
cp "$WIDGET_INFO" "$BACKUP_DIR/WidgetExtensionInfo.plist"

perl -0pi -e "s/DEVELOPMENT_TEAM = [A-Z0-9]+;/DEVELOPMENT_TEAM = $TEAM_ID;/g" "$PROJECT_FILE"
perl -0pi -e "s/PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.]+\\.SpotWidgetExtension;/PRODUCT_BUNDLE_IDENTIFIER = $EXTENSION_BUNDLE_ID;/g" "$PROJECT_FILE"
perl -0pi -e "s/PRODUCT_BUNDLE_IDENTIFIER = [A-Za-z0-9.]+\\.SpotWidget;/PRODUCT_BUNDLE_IDENTIFIER = $APP_BUNDLE_ID;/g" "$PROJECT_FILE"

/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$APP_INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP_INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLName $APP_BUNDLE_ID" "$APP_INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$WIDGET_INFO"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}Extension" "$WIDGET_INFO"

cat <<DONE
Prepared project for another Apple Developer account.

App name:
  $APP_NAME

App bundle ID:
  $APP_BUNDLE_ID

Widget extension bundle ID:
  $EXTENSION_BUNDLE_ID

Team ID:
  $TEAM_ID

Backup saved to:
  $BACKUP_DIR

Next:
1. Open Xcode and sign in to the other Apple account.
2. Select the friend's team for both targets if Xcode asks.
3. Archive again.
4. Upload to App Store Connect under that account.
DONE
