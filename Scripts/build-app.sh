#!/bin/bash
# Assembles Mist.app from the SwiftPM build output. There's no full
# Xcode on this machine (Command Line Tools only), so there's no .xcodeproj
# to build an app bundle from directly — this does it by hand: swift build,
# then wrap the executable in a standard Contents/{MacOS,Resources} bundle
# with Info.plist and AppIcon.icns, then ad-hoc codesign it so Gatekeeper
# and LaunchServices treat it as a normal local app.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${1:-debug}"
APP_NAME="Mist"
APP_BUNDLE=".build/${APP_NAME}.app"

echo "Building (${CONFIGURATION})…"
swift build -c "$CONFIGURATION"

BINARY_PATH=".build/${CONFIGURATION}/${APP_NAME}"
if [ ! -f "$BINARY_PATH" ]; then
    echo "error: built binary not found at $BINARY_PATH" >&2
    exit 1
fi

echo "Assembling ${APP_BUNDLE}…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Version stamping: VERSION file is the single source of truth for the
# marketing version; the build number is the git commit count.
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
echo "Stamping version ${VERSION} (${BUILD_NUMBER})…"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

echo "Codesigning (ad-hoc)…"
codesign --force --deep --sign - --entitlements Mist.entitlements "$APP_BUNDLE"

# Refresh the installed copy so Spotlight/Dock/Finder always launch the
# latest build. ditto preserves the bundle structure and signature; set
# MIST_SKIP_INSTALL=1 to build without touching /Applications.
INSTALL_PATH="/Applications/${APP_NAME}.app"
if [ "${MIST_SKIP_INSTALL:-0}" != "1" ]; then
    echo "Installing to ${INSTALL_PATH}…"
    rm -rf "$INSTALL_PATH"
    ditto "$APP_BUNDLE" "$INSTALL_PATH"
    echo "Done: $APP_BUNDLE (installed at $INSTALL_PATH)"
else
    echo "Done: $APP_BUNDLE"
fi
