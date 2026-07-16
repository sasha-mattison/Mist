#!/bin/bash
# Publishes a GitHub Release for the version currently in VERSION: builds a
# release .dmg (human-facing download, via make-dmg.sh) and a .zip of the
# same build (what UpdateInstaller.swift downloads and expands for in-app
# updates), tags the commit, and uploads both via `gh release create`.
#
# Prerequisites (one-time, done by you — not automatable from here):
#   - VERSION and CHANGELOG.md already bumped/committed for this release.
#   - GitHub CLI installed and authenticated: `brew install gh && gh auth login`.
#   - The sasha-mattison/Mist repo is public (the in-app update checker
#     reads the Releases API unauthenticated, so a private repo can't work).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Mist"
VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v${VERSION}"
DIST_DIR=".build/dist"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
APP_BUNDLE=".build/${APP_NAME}.app"

if ! command -v gh >/dev/null 2>&1; then
    echo "error: GitHub CLI not found. Install with: brew install gh, then: gh auth login" >&2
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh is not authenticated. Run: gh auth login" >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "error: working tree isn't clean — commit or stash changes before releasing." >&2
    exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "error: tag $TAG already exists — bump VERSION first." >&2
    exit 1
fi

RELEASE_NOTES="$(awk -v ver="$VERSION" '
    $0 ~ "^## " ver " " { found=1; next }
    /^## / && found { exit }
    found { print }
' CHANGELOG.md)"
if [ -z "$(echo "$RELEASE_NOTES" | tr -d '[:space:]')" ]; then
    echo "error: no \"## ${VERSION} — ...\" section found in CHANGELOG.md — add release notes first." >&2
    exit 1
fi

echo "Building ${APP_NAME} ${VERSION}…"
MIST_SKIP_INSTALL=1 ./Scripts/make-dmg.sh release

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: ${APP_BUNDLE} not found after build" >&2
    exit 1
fi

echo "Zipping ${ZIP_PATH} for the in-app updater…"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
echo "$RELEASE_NOTES" > "$NOTES_FILE"

echo "Tagging ${TAG}…"
git tag -a "$TAG" -m "Mist ${VERSION}"
git push origin "$TAG"

echo "Creating GitHub release…"
gh release create "$TAG" "$DMG_PATH" "$ZIP_PATH" \
    --title "Mist ${VERSION}" \
    --notes-file "$NOTES_FILE"

echo "Done: published ${TAG}"
