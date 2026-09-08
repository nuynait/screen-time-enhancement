#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
modules="$sdk_path/System/Library/Frameworks/ManagedSettings.framework/Modules"
# Use the macOS-provided grep so a fresh checkout does not require ripgrep.
if /usr/bin/grep -R -q 'case openParentalControlsApp' "$modules"; then
    printf 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) SCREEN_TIME_CAN_OPEN_APP\n' > Config/SDK.xcconfig
    echo "Direct shield-to-app handoff enabled for iOS 26.5+."
else
    printf '// This SDK lacks openParentalControlsApp. Use the notification/manual handoff.\n' > Config/SDK.xcconfig
    echo "Using notification/manual handoff. Regenerate with an iOS 26.5+ SDK to enable direct opening."
fi
xcodegen generate
