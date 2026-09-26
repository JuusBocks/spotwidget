#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
VERSION=""
PRERELEASE_FLAG="--prerelease"
DRAFT_FLAG=""

usage() {
  cat <<'USAGE'
Usage: ./scripts/release-github.sh --version VERSION [--team-id TEAM_ID] [--stable] [--draft]

Builds a release zip with scripts/package-app.sh and publishes it to GitHub
Releases as vVERSION.

Options:
  --version VERSION   Release version, for example 0.1.0.
  --team-id TEAM_ID   Apple Developer Team ID. Optional after signing is
                      already configured in Xcode.
  --stable            Publish as a normal release instead of a prerelease.
  --draft             Create a draft release.
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      if [[ -z "$VERSION" ]]; then
        echo "Missing value for --version" >&2
        exit 2
      fi
      shift 2
      ;;
    --team-id)
      TEAM_ID="${2:-}"
      if [[ -z "$TEAM_ID" ]]; then
        echo "Missing value for --team-id" >&2
        exit 2
      fi
      shift 2
      ;;
    --stable)
      PRERELEASE_FLAG=""
      shift
      ;;
    --draft)
      DRAFT_FLAG="--draft"
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

if [[ -z "$VERSION" ]]; then
  echo "Missing required --version" >&2
  usage
  exit 2
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI was not found. Install gh and authenticate first." >&2
  exit 1
fi

PACKAGE_ARGS=(--version "$VERSION")
if [[ -n "$TEAM_ID" ]]; then
  PACKAGE_ARGS+=(--team-id "$TEAM_ID")
fi

"$ROOT_DIR/scripts/package-app.sh" "${PACKAGE_ARGS[@]}"

ZIP_PATH="$ROOT_DIR/dist/Widgify-$VERSION-macOS.zip"
SHA_PATH="$ZIP_PATH.sha256"
TAG="v$VERSION"

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG already exists. Delete it or choose another version." >&2
  exit 1
fi

gh release create "$TAG" "$ZIP_PATH" "$SHA_PATH" \
  --target main \
  --title "Widgify $VERSION" \
  --notes "Widgify $VERSION for macOS. Download the zip, unzip it, move Widgify.app to /Applications, open it once, then add the widget from Edit Widgets. This build is intended for private testing unless it has been Developer ID signed and notarized." \
  $PRERELEASE_FLAG \
  $DRAFT_FLAG
