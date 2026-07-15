#!/bin/bash
# Assembles SteamClient.app from the SwiftPM build output. There's no full
# Xcode on this machine (Command Line Tools only), so there's no .xcodeproj
# to build an app bundle from directly — this does it by hand: swift build,
# then wrap the executable in a standard Contents/{MacOS,Resources} bundle
# with Info.plist and AppIcon.icns, then ad-hoc codesign it so Gatekeeper
# and LaunchServices treat it as a normal local app.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${1:-debug}"
APP_NAME="SteamClient"
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

echo "Codesigning (ad-hoc)…"
codesign --force --deep --sign - --entitlements SteamClient.entitlements "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
