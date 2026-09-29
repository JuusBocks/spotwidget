#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
DELETE_DERIVED_DATA=1
DOWNLOADS_DIR="${HOME}/Downloads"

usage() {
  cat <<'USAGE'
Usage: ./scripts/clean-test-install.sh [--dry-run] [--keep-derived-data]

Removes local Widgify test installs and stale widget registrations so a fresh
GitHub DMG can be tested cleanly.

Actions:
  - Quit Widgify if it is running.
  - Unregister Widgify and old SpotifyWidget widget extensions from PluginKit.
  - Remove /Applications/Widgify.app and old /Applications/Spotify Widget.app.
  - Remove old Widgify/SpotifyWidgetMac Xcode DerivedData folders.
  - Delete the newest Widgify macOS DMG from Downloads.
  - Refresh WidgetKit and Launch Services caches.

Options:
  --dry-run             Print what would be removed without deleting anything.
  --keep-derived-data   Do not remove matching Xcode DerivedData folders.
  -h, --help            Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --keep-derived-data)
      DELETE_DERIVED_DATA=0
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

run() {
  printf '• %s\n' "$*"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    "$@" || true
  fi
}

remove_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    run rm -rf "$path"
  fi
}

unregister_plugin_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    run pluginkit -r "$path"
  fi
}

echo "Cleaning Widgify test install..."

run pkill -x Widgify

unregister_plugin_path "/Applications/Widgify.app/Contents/PlugIns/WidgifyExtension.appex"
unregister_plugin_path "/Applications/Widgify.app/Contents/PlugIns/SpotifyWidgetExtension.appex"
unregister_plugin_path "/Applications/Spotify Widget.app/Contents/PlugIns/SpotifyWidgetExtension.appex"
unregister_plugin_path "/Applications/Spotify Widget.app/Contents/PlugIns/WidgifyExtension.appex"

if command -v pluginkit >/dev/null 2>&1; then
  while IFS= read -r plugin_path; do
    unregister_plugin_path "$plugin_path"
  done < <(
    pluginkit -m -A -D -v 2>/dev/null |
      awk '/com\.leounib\.Widgify\.(WidgifyExtension|SpotifyWidgetExtension)/ { print $NF }'
  )
fi

remove_path "/Applications/Widgify.app"
remove_path "/Applications/Spotify Widget.app"

if [[ "$DELETE_DERIVED_DATA" -eq 1 ]]; then
  for path in \
    "${HOME}/Library/Developer/Xcode/DerivedData/Widgify-"* \
    "${HOME}/Library/Developer/Xcode/DerivedData/SpotifyWidgetMac-"*
  do
    [[ -e "$path" ]] && remove_path "$path"
  done
fi

latest_dmg="$(
  find "$DOWNLOADS_DIR" -maxdepth 1 -type f \( \
      -name 'Widgify-*-macOS*.dmg' -o \
      -name 'widgify-*-macOS*.dmg' -o \
      -name 'Widgify*.dmg' -o \
      -name 'widgify*.dmg' \
    \) -print0 2>/dev/null |
    xargs -0 ls -t 2>/dev/null |
    head -n 1 || true
)"

if [[ -n "$latest_dmg" ]]; then
  remove_path "$latest_dmg"
else
  echo "• No Widgify DMG found in Downloads"
fi

if [[ -d "/Volumes/Widgify" ]]; then
  run hdiutil detach "/Volumes/Widgify"
fi

run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain user
run killall chronod
run killall WidgetKitExtension

cat <<'DONE'

Widgify test install cleanup complete.

Next:
1. Download the newest DMG from GitHub.
2. Drag Widgify.app to Applications.
3. Open Widgify once.
4. Open the widget picker and add Widgify again.
DONE
