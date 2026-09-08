#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
simulator_id="$(python3 scripts/select-simulator.py "${1:-}")"
./scripts/build.sh
# The selector can return an already booted phone. bootstatus checks that it is usable.
xcrun simctl boot "$simulator_id" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_id" -b
open -a Simulator
xcrun simctl install "$simulator_id" build/DerivedData/Build/Products/Debug-iphonesimulator/Gate.app
app_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' build/DerivedData/Build/Products/Debug-iphonesimulator/Gate.app/Info.plist)"
xcrun simctl terminate "$simulator_id" "$app_bundle_id" 2>/dev/null || true
xcrun simctl launch "$simulator_id" "$app_bundle_id" --demo
