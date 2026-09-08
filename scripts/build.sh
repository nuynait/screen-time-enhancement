#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/generate.sh
xcodebuild -project ScreenTimeEnhancement.xcodeproj -scheme Gate -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=NO build "$@"
