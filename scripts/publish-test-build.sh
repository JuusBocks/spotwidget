#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
TAG="v$VERSION"

cd "$ROOT_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash local changes before publishing." >&2
  exit 1
fi

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Publish from the main branch." >&2
  exit 1
fi

git push origin main
git tag -f "$TAG"
git push --force origin "$TAG"

"$ROOT_DIR/scripts/package-app.sh" --version "$VERSION"

gh release view "$TAG" >/dev/null
gh release upload "$TAG" \
  "$ROOT_DIR/dist/SpotWidget-$VERSION-macOS.dmg" \
  "$ROOT_DIR/dist/SpotWidget-$VERSION-macOS.dmg.sha256" \
  "$ROOT_DIR/dist/SpotWidget-$VERSION-macOS.zip" \
  "$ROOT_DIR/dist/SpotWidget-$VERSION-macOS.zip.sha256" \
  --clobber

"$ROOT_DIR/scripts/clean-test-install.sh"

echo "Published $TAG and removed the local test install."
