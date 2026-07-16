#!/bin/bash
# Packages Mist.app into a distributable, installable .dmg for sharing with
# other people. Does a fresh release build (no dev-machine debug artifacts),
# then stages a clean copy of the bundle before imaging it: extended
# attributes (Gatekeeper quarantine flags, Finder tags/comments, download
# provenance), ACLs, and .DS_Store files can all carry this Mac's or this
# user's fingerprints, so they're stripped from the staged copy. The app
# bundle itself never contains user data (Mist keeps prefs in UserDefaults,
# secrets in Keychain, cached library data under ~/Library/Application
# Support — all outside the bundle), so this is a hardening pass, not a
# scrub of the app's own contents.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Mist"
CONFIGURATION="${1:-release}"
VERSION="$(tr -d '[:space:]' < VERSION)"
DIST_DIR=".build/dist"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"
APP_BUNDLE=".build/${APP_NAME}.app"

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Building ${APP_NAME} (${CONFIGURATION})…"
MIST_SKIP_INSTALL=1 ./Scripts/build-app.sh "$CONFIGURATION"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: ${APP_BUNDLE} not found" >&2
    exit 1
fi

echo "Staging a clean copy…"
# --noextattr / --noacl drop extended attributes and ACLs picked up on this
# machine; xattr -cr and the .DS_Store sweep catch anything ditto missed.
ditto --noextattr --noacl "$APP_BUNDLE" "$STAGING_DIR/${APP_NAME}.app"
xattr -cr "$STAGING_DIR/${APP_NAME}.app"
find "$STAGING_DIR" -name ".DS_Store" -delete

echo "Adding Applications shortcut…"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "Creating $(basename "$DMG_PATH")…"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" >/dev/null

echo "Done: ${DMG_PATH}"
