#!/usr/bin/env bash
# Fast iterate-on-device loop: build the Debug app and install+launch it on a
# connected iPhone — no build-number bump, no TestFlight processing wait.
#
# Usage:
#   ./run-on-device.sh                 # auto-detect device, launch normally (hits the paywall)
#   ./run-on-device.sh --unlocked      # launch past the hard paywall (DEBUG -uiTestUnlocked)
#   ./run-on-device.sh <UDID>          # target a specific device
#   ./run-on-device.sh <UDID> --unlocked
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID="com.ayushgupta.glpill"

# Parse args: a UUID-looking token is the device; --unlocked bypasses the paywall.
UDID=""
UNLOCKED=""
for arg in "$@"; do
  case "$arg" in
    --unlocked) UNLOCKED=1 ;;
    *) UDID="$arg" ;;
  esac
done

# Fall back to the first "connected" iPhone/iPad (works over USB or Wi-Fi pairing).
UDID="${UDID:-$(xcrun devicectl list devices 2>/dev/null \
  | grep -iE 'iphone|ipad' | grep -i 'connected' \
  | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' \
  | head -1)}"

if [ -z "${UDID:-}" ]; then
  echo "❌ No connected iOS device found."
  echo "   Plug in your iPhone (or ensure it's on the same Wi-Fi if paired wirelessly),"
  echo "   unlock it, tap 'Trust', and confirm Developer Mode is ON."
  exit 1
fi
echo "📱 Device: $UDID   ${UNLOCKED:+(unlocked)}"

echo "⚙️  xcodegen…"
xcodegen generate >/dev/null

echo "🔨 Building (Debug, for device)…"
xcodebuild -project GLPill.xcodeproj -scheme GLPill -configuration Debug \
  -destination "id=$UDID" -allowProvisioningUpdates -derivedDataPath build/dd \
  build | tail -1

APP="build/dd/Build/Products/Debug-iphoneos/GLPill.app"
[ -d "$APP" ] || { echo "❌ Build product missing: $APP"; exit 1; }

echo "📥 Installing…"
xcrun devicectl device install app --device "$UDID" "$APP" >/dev/null

echo "🚀 Launching…"
# NOTE: app args must follow a `--` separator, else devicectl parses "-uiTestUnlocked"
# as bundled short flags (it hits -t/--timeout and errors).
if [ -n "$UNLOCKED" ]; then
  xcrun devicectl device process launch --terminate-existing --device "$UDID" "$BUNDLE_ID" -- -uiTestUnlocked >/dev/null
else
  xcrun devicectl device process launch --terminate-existing --device "$UDID" "$BUNDLE_ID" >/dev/null
fi

echo "✅ Installed + launched on device."
