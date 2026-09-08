#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f Config/Local.xcconfig ]; then
    echo "Copy Config/Local.xcconfig.example to Config/Local.xcconfig and set your team and unique bundle ID first." >&2
    exit 1
fi
if /usr/bin/grep -Eq '^[[:space:]]*(DEVELOPMENT_TEAM|GATE_BUNDLE_ID)[[:space:]]*=[[:space:]]*(YOUR_TEAM_ID|com\.yourname\.)' Config/Local.xcconfig; then
    echo "Replace the example team and bundle ID in Config/Local.xcconfig before signing." >&2
    exit 1
fi
./scripts/generate.sh
xcodebuild -project ScreenTimeEnhancement.xcodeproj -scheme Gate -configuration Debug \
    -destination 'generic/platform=iOS' -derivedDataPath build/DeviceData \
    -allowProvisioningUpdates build "$@"
